//
//  GitHubAPIProvider.swift
//  Technical Assessment
//
//  Created by Elliot Garner on 9/25/24.
//

import Foundation

// Ideally you would authenticate on behalf of the user, or store this somewhere *much* more secure than plain text.

class GitHubAPIProvider {
    private static let accessToken = "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"
    private static let url = URL(string: "https://api.github.com")

    private static func attachHeaders(to request: inout URLRequest) {
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
    }

    static func search(for user: String) async throws -> Result<FetchResponse<User>, Error> {
        guard var url else {
            fatalError("API Url is invalid")
        }

        let request = Requests.fetchUser(userID: user)
        url = url.appendingPathComponent(request.path)

        return await fetch(classType: User.self, from: url)
    }

    static func fetchAllUsers(pageURLString: String? = nil) async throws -> Result<FetchResponse<[User]>, Error> {
        var fetchUsersURL: URL
        if pageURLString == nil {
            guard let url else {
                fatalError("API Url is invalid")
            }

            let request = Requests.fetchAllUsers
            fetchUsersURL = url.appendingPathComponent(request.path)
        } else {
            guard let pageURLString,
                  let url = URL(string: pageURLString) else {
                fatalError("API URL is invalid")
            }

            fetchUsersURL = url
        }

        return await fetch(classType: [User].self, from: fetchUsersURL)
    }

    static func countUsers(from urlString: String) async -> Int {
        let result = await fetch(classType: [User].self, from: urlString)
        switch result {
        case .success(let fetchResponse):
            if let linkHeader = fetchResponse.linkHeader,
               let lastPageIndex = linkHeader.lastPageIndex,
               let lastPageURLString = linkHeader.lastPageURLString {
                let lastPageResult = await apiProvider.fetch(classType: [User].self, from: lastPageURLString)
                let tempFollowerCount = (lastPageIndex - 1) * 30
                switch lastPageResult {
                case .success(let lastPageFetchResponse):
                    return tempFollowerCount + lastPageFetchResponse.response.count
                case .failure(_):
                    return tempFollowerCount
                }
            } else {
                return fetchResponse.response.count
            }
        case .failure(_):
            return 0
        }
    }


    // Fetch data from the URL provided in a previous query response
    static func fetch<T>(classType: T.Type, from urlString: String) async -> Result<FetchResponse<T>, Error> where T : Decodable {
        guard let url = URL(string: urlString) else {
            return .failure(APIError.internalError)
        }

        return await fetch(classType: classType, from: url)
    }

    static func fetch<T>(classType: T.Type, from url: URL) async -> Result<FetchResponse<T>, Error> where T : Decodable {
        var urlRequest = URLRequest(url: url)
        attachHeaders(to: &urlRequest)
        do {
            let (data, response) = try await URLSession.shared.data(for: urlRequest)
            let result = try JSONDecoder().decode(classType, from: data)
            let linkHeader = getLinkHeader(from: response)
            let fetchResponse = FetchResponse(response: result, linkHeader: linkHeader)
            return .success(fetchResponse)
        } catch let error {
            print(error)
            return .failure(APIError.internalError)
        }
    }

    static func getLinkHeader(from response: URLResponse) -> String? {
        guard let response = response as? HTTPURLResponse,
              let linkResponse = response.value(forHTTPHeaderField: "link") else {
            return nil
        }

        return linkResponse
    }
}

// State objects
extension GitHubAPIProvider {
    struct FetchResponse<T> where T: Decodable {
        var response: T
        var linkHeader: LinkHeaders?

        init(response: T, linkHeader: String?) {
            self.response = response
            if let linkHeader {
                self.linkHeader = LinkHeaders(linkHeader)
            }
        }

        // Link header is in the format of "<https://api.github.com/users?since=46>; rel=\"next\", <https://api.github.com/users{?since}>; rel=\"first\""
        // Ideally you would use a LinkParser package / framework or write something that isnt so quick and dirty, but this will do.
        struct LinkHeaders {
            private var header: String

            init(_ header: String) {
                self.header = header.filter { !$0.isWhitespace }
            }

            var nextPageURLString: String? {
                getURLWith(identifier: "next")
            }

            var lastPageURLString: String? {
                return getURLWith(identifier: "last")
            }

            var lastPageIndex: Int? {
                guard var pageIndex = lastPageURLString else {
                    return nil
                }

                guard let index = pageIndex.lastIndex(of: "=") else {
                    return nil
                }

                pageIndex.removeSubrange(pageIndex.startIndex...index)
                return Int(pageIndex)
            }

            private func getURLWith(identifier: String) -> String? {
                let relList = header.split(separator: ",")
                for rel in relList {
                    let splitList = rel.split(separator: ";")
                    guard let isLastPage = splitList.last?.contains("\(identifier)"),
                          isLastPage,
                          let urlString = splitList.first else {
                        continue
                    }

                    return urlString.trimmingCharacters(in: CharacterSet(charactersIn: "<>"))
                }

                return nil
            }
        }    }

    enum Requests {
        case fetchUser(userID: String)
        case fetchAllUsers

        var path: String {
            switch self {
            case .fetchUser(let userID):
                return "/users/\(userID)"
            case .fetchAllUsers:
                return "/users"
            }
        }
    }

    struct APIErrorResponse: Decodable {
        var message: String
        var status: String

        var error: APIError {
            switch message {
            case "Not Found":
                return .notFound
            default:
                return .internalError
            }
        }
    }

    enum APIError: Error, Identifiable {
        case internalError
        case notFound

        var id: UUID { UUID() }
        var title: String {
            switch self {
            case .notFound:
                return "User not found"
            case .internalError:
                return "Error"
            }
        }

        var message: String {
            switch self {
            case .notFound:
                return "The user requested does not exist."
            case .internalError:
                return "There was an error connecting to the network.  Please try again later."
            }
        }

    }

    struct UserListFetchResult {
        var listOfUsers: [User]
        var nextPageURL: String?
    }

}
