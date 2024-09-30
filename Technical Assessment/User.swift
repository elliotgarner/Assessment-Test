//
//  User.swift
//  Technical Assessment
//
//  Created by Elliot Garner on 9/25/24.
//

import Foundation
import SwiftUI

class User: Identifiable, Codable, ObservableObject {
    var username: String
    var fullName: String?
    var reposURLString: String
    var profilePictureURLString: String
    var followersURLString: String

    // Backing variable
    private var _followingURLString: String
    var followingURLString: String {
        // strip out the {}
        var urlString = _followingURLString
        guard let index = urlString.firstIndex(of: "{") else {
            return _followingURLString
        }

        urlString.removeSubrange(index..<urlString.endIndex)
        return urlString
    }


    @Published var followerCount: Int = 0
    @Published var followingCount: Int = 0
    @Published var repos: [User.Repo] = [] {
        didSet {
            Task.detached {
                for repo in self.repos {
                    await repo.fetchLanguages()
                }
            }
        }
    }

    var id: String { username }

    private enum CodingKeys: String, CodingKey {
        case username = "login"
        case fullName = "name"
        case profilePictureURLString = "avatar_url"
        case _followingURLString = "following_url"
        case followersURLString = "followers_url"
        case reposURLString = "repos_url"
    }

    // Load data that could be expensive to fetch in the list view.
    func loadUserDetails() async {
        await fetchFollowers()
        await fetchFollowing()
        await fetchRepos()
    }

    // Do these lazily since we dont want to pay the costs of hitting the API for
    // every fetch, only when looking at the specific user.
    private func fetchFollowing() async {
        let count = await apiProvider.countUsers(from: followingURLString)
        await MainActor.run {
            followingCount = count
        }
    }

    private func fetchFollowers() async {
        let count = await apiProvider.countUsers(from: followersURLString)
        await MainActor.run {
            followerCount = count
        }
    }

    // TODO: Only currently supporting showing 30 repos.
    // If wanted to see more, copy the "isLast" logic from the UserSearchViewModel
    private func fetchRepos() async {
        let result = await apiProvider.fetch(classType: [Repo].self, from: reposURLString)
        await MainActor.run {
            switch result {
            case .success(let fetchResponse):
                self.repos = fetchResponse.response
            case .failure(_):
                break
            }
        }
    }
}

extension User {
    class Repo: Codable, Identifiable {
        var name: String
        var description: String?
        var urlString: String
        var isFork: Bool
        var languagesURLString: String
        var languages: [String] = []
        var stars: Int

        var id: String { urlString }
        enum CodingKeys: String, CodingKey {
            case name, description
            case urlString = "html_url"
            case isFork = "fork"
            case languagesURLString = "languages_url"
            case stars = "stargazers_count"
        }

        func fetchLanguages() async {
            let result = await apiProvider.fetch(classType: [String: Int].self, from: languagesURLString)
            await MainActor.run {
                switch result {
                case .success(let fetchResponse):
                    let languages = fetchResponse.response
                    self.languages = getLanguagesOrderedByUse(languages: languages)
                case .failure(_):
                    break
                }
            }
        }

        // Sort the keys in order from highest to lowest
        func getLanguagesOrderedByUse(languages languagesDict: [String: Int]) -> [String] {
            let languagesTupleArray = languagesDict.sorted(using: KeyPathComparator(\.value, order: .reverse))
            return languagesTupleArray.map { $0.key }
        }
    }
}

// MARK: Preview Data

class PreviewUser: User {
    override func loadUserDetails() async {
        loadPreviewData()
    }

    func loadPreviewData() {
        loadPreviewRepos()
        loadPreviewLanguages()
        followerCount = 10
        followingCount = 20
    }

    private func loadPreviewRepos() {
        let urlString = Bundle.main.path(forResource: "PreviewRepo", ofType: "json")!
        let userURL = URL(fileURLWithPath: urlString)
        let data = try! Data(contentsOf: userURL)
        let repos = try! JSONDecoder().decode([User.Repo].self, from: data)
        self.repos = repos.filter { !$0.isFork }
    }

    private func loadPreviewLanguages() {
        let urlString = Bundle.main.path(forResource: "PreviewLanguages", ofType: "json")!
        let userURL = URL(fileURLWithPath: urlString)
        let data = try! Data(contentsOf: userURL)
        let languagesDict = try! JSONDecoder().decode([String: Int].self, from: data)
        for repo in repos {
            repo.languages = repo.getLanguagesOrderedByUse(languages: languagesDict)
        }
    }
}

extension User {
    // This is NOT SAFE to call outside of a preview
    // Is there a way to fatalError is the current scheme is not Preview?
    static var previewUser: User {
        let urlString = Bundle.main.path(forResource: "PreviewUser", ofType: "json")!
        let userURL = URL(fileURLWithPath: urlString)
        let data = try! Data(contentsOf: userURL)
        let user = try! JSONDecoder().decode(PreviewUser.self, from: data)
        return user
    }
}
