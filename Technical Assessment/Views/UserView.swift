//
//  UserView.swift
//  Technical Assessment
//
//  Created by Elliot Garner on 9/28/24.
//

import SwiftUI

struct UserView: View {
    @ObservedObject
    var user: User

    @Environment(\.openURL)
    private var openURL


    var body: some View {
        List {
            Section {
                HStack {
                    Spacer()
                    VStack {
                        AsyncImage(
                            url: URL(
                                string: user.profilePictureURLString
                            ),
                            content: { phase in
                                if let image = phase.image {
                                    image
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                }
                            }
                        )
                        .clipShape(.circle)
                        .frame(width: 100, height: 100)
                        Text(user.username)
                            .font(.largeTitle)
                        if let fullName = user.fullName {
                            Text(fullName)
                                .font(.title)
                        }

                        HStack {
                            Text("Followers: \(user.followerCount)")
                            Text("Following: \(user.followingCount)")
                        }
                    }
                    Spacer()
                }
            }

            ForEach(0 ..< user.repos.count, id: \.self) {
                let repo = user.repos[$0]
                if let url = URL(string: repo.urlString) {
                    Button(
                        action: {
                            openURL(url)
                        }
                    ) {
                        RepositoryView(repo: repo)
                    }
                    .tint(.black)
                }
            }
        }
        .task {
            await user.loadUserDetails()
        }
    }
}

#Preview {
    UserView(user: User.previewUser)
}
