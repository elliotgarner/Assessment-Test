//
//  UserSearchView.swift
//  Technical Assessment
//
//  Created by Elliot Garner on 9/25/24.
//

import SwiftUI

typealias apiProvider = GitHubAPIProvider

class UserSearch: ObservableObject {
    var provider: apiProvider.Type
    var nextPageURLString: String? = nil
    @Published var listOfUsers: [User] = []

    init(provider: apiProvider.Type) {
        self.provider = provider
    }


    // Potential optimization:
    // Preload the data by not checking last, but index within N of the last.
    func isLast(user: User) -> Bool {
        return user.id == listOfUsers.last?.id
    }

    func loadNextPage() async throws {
        let result = try await provider.fetchAllUsers(pageURLString: nextPageURLString)
        switch result {
        case .success(let fetchResponse):
            await MainActor.run {
                listOfUsers.append(contentsOf: fetchResponse.response)
                nextPageURLString = fetchResponse.linkHeader?.nextPageURLString
            }
        case .failure(let error):
            throw error
        }
    }
}


struct UserSearchView: View {
    @State var searchString: String = ""
    @State var isLoading = true
    @State var selectedUser: User? = nil
    @State var showingUserProfile = false
    @State var apiError: apiProvider.APIError? = nil

    @ObservedObject
    var model: UserSearch = UserSearch(provider: apiProvider.self)

    var body: some View {
        NavigationStack {
            ZStack {
                if self.isLoading {
                    ProgressView()
                }
                List(model.listOfUsers) { user in
                    Button(
                        action: {
                            selectedUser = user
                            showingUserProfile = true
                        }
                    ) {
                        UserSearchResultRowView(user: user)
                    }
                    .tint(.black)
                    .listRowInsets(.init())
                    .task {
                        if model.isLast(user: user) {
                            do {
                                try await model.loadNextPage()
                            } catch let error {
                                showAlert(for: error)
                            }
                        }
                    }


                }
                .environment(\.defaultMinListRowHeight, 0)
                .navigationDestination(isPresented: $showingUserProfile) {
                    if let selectedUser {
                        UserView(user: selectedUser)
                    }
                }
            }
        }
        .searchable(text: $searchString, prompt: "User Name")
        .onSubmit(of: .search) {
            self.isLoading = true
            Task.detached {
                await searchForUser()
            }
        }
        .alert(item: $apiError) { error in
            Alert(title: Text(error.title), message: Text(error.message))
        }
        .task {
            do {
                try await model.loadNextPage()
            } catch let error {
                showAlert(for: error)
            }
        }
    }

    nonisolated func searchForUser() async {
        do {
            let result = try await apiProvider.search(for: searchString)
            await MainActor.run { [result] in
                isLoading = false

                switch result {
                case .success(let fetchResponse):
                    selectedUser = fetchResponse.response
                    showingUserProfile = true
                case .failure(let error):
                    showAlert(for: error)
                }
            }
        } catch let error {
            print("Couldnt fetch GitHub users: \(error)")
        }
    }

    func showAlert(for error: Error) {
        if let error = error as? GitHubAPIProvider.APIError {
            apiError = error
        } else {
            print("Unexpected error \(error)")
            apiError = .internalError
        }
    }
}

#Preview {
    UserSearchView()
}
