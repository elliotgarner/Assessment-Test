//
//  UserSearchResultRowView.swift
//  Technical Assessment
//
//  Created by Elliot Garner on 9/27/24.
//

import Foundation
import SwiftUI

struct UserSearchResultRowView: View {
    var user: User

    var body: some View {
        HStack {
            AsyncImage(
                url: URL(string: user.profilePictureURLString),
                content: { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                }
            )
            .clipShape(.circle)
            .frame(width: 50, height: 50)
            Text(user.username)
            Spacer()
        }
        .padding()
    }
}

#Preview {
    UserSearchResultRowView(user: User.previewUser)
}
