//
//  RepositoryView.swift
//  Technical Assessment
//
//  Created by Elliot Garner on 9/28/24.
//

import SwiftUI

struct RepositoryView: View {
    let repo: User.Repo
    
    var body: some View {
        VStack {
            // Repository names canot have spaces in them.
            // This means if they're too long they break in weird places.
            // Technically you could get more options as to how the line-
            // breaks work if you wrapped this in a custom UILabel.
            Text(repo.name)
                .font(.title)
                .multilineTextAlignment(.center)

            if let description = repo.description {
                Text(description)
                    .multilineTextAlignment(.center)
            }
            Spacer()

            // Swift Bug?  It thinks URL isnt used despite being present in the markdown text.
            // Only show a maximum of 3 languages
            let languages = repo.languages
            Text("Languages")
                .font(.headline)
            HStack {
                Spacer()
                // Only show 3 highest languages.
                ForEach(0 ..< 3) {
                    if languages.indices.contains($0) {
                        let language = repo.languages[$0]
                        Text(language)
                    }
                }
                Spacer()
            }
            Spacer()
            Text("Stars: \(repo.stars)")
        }
    }
}

#Preview {
    let user = User.previewUser as! PreviewUser
    user.loadPreviewData()
    return RepositoryView(repo: user.repos.first!)
}
