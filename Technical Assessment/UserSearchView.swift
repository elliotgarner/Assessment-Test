//
//  UserSearchView.swift
//  Technical Assessment
//
//  Created by Elliot Garner on 9/25/24.
//

import SwiftUI

struct UserSearchView: View {
    @State var searchString: String = ""
    @State var string: String = "Other Test"
    @State var isLoading = false
    var body: some View {
        NavigationStack {
            if isLoading {
                ProgressView()
            } else {
                List {
                    Text("Test")
                    Text(string)
                }
            }
        }
        .searchable(text: $searchString, prompt: "User Name")
        .onSubmit(of: .search) {
            searchForUser()
        }
    }

    func searchForUser() {
        string = searchString
        isLoading = true
    }
}

#Preview {
    UserSearchView()
}
