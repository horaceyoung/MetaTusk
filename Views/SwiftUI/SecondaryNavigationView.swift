// Copyright © 2020 Metabolist. All rights reserved.

import SwiftUI
import ViewModels

struct SecondaryNavigationView: View {
    @ObservedObject var viewModel: NavigationViewModel
    @EnvironmentObject var rootViewModel: RootViewModel
    @Environment(\.displayScale) var displayScale: CGFloat

    var body: some View {
        Form {
            Section {
                if let id = viewModel.identityContext.identity.account?.id {
                    Button {
                        viewModel.navigateToProfile(id: id)
                    } label: {
                        Label {
                            Text("secondary-navigation.my-profile").foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "person.crop.square")
                        }
                    }
                }
                if let instanceURI = viewModel.identityContext.identity.instance?.uri {
                    Button {
                        viewModel.navigateToEditProfile(instanceURI: instanceURI)
                    } label: {
                        Label {
                            Text("secondary-navigation.edit-profile").foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "pencil")
                        }
                    }
                    Button {
                        viewModel.navigateToAccountSettings(instanceURI: instanceURI)
                    } label: {
                        Label {
                            Text("secondary-navigation.account-settings").foregroundColor(.primary)
                        } icon: {
                            Image(systemName: "person.crop.square.filled.and.at.rectangle")
                        }
                    }
                }
                NavigationLink(
                    destination: IdentitiesView { .init(identityContext: viewModel.identityContext) }
                        .environmentObject(rootViewModel)) {
                    Label("secondary-navigation.accounts", systemImage: "rectangle.stack.person.crop")
                }
            }
            if viewModel.identityContext.identity.authenticated && !viewModel.identityContext.identity.pending {
                Section {
                    NavigationLink(destination: ListsView(viewModel: .init(identityContext: viewModel.identityContext))
                                    .environmentObject(rootViewModel)) {
                        Label("secondary-navigation.lists", systemImage: "scroll")
                    }
                    NavigationLink(
                        destination: FollowedTagsView(viewModel: .init(identityContext: viewModel.identityContext))
                            .environmentObject(rootViewModel)) {
                        Label("secondary-navigation.followed-tags", systemImage: "number")
                    }
                    ForEach([Timeline.favorites, Timeline.bookmarks]) { timeline in
                        Button {
                            viewModel.navigate(timeline: timeline)
                        } label: {
                            Label {
                                Text(timeline.title).foregroundColor(.primary)
                            } icon: {
                                Image(systemName: timeline.systemImageName)
                            }
                        }
                    }
                    if let followRequestCount = viewModel.identityContext.identity.account?.followRequestCount,
                       followRequestCount > 0 {
                        Button {
                            viewModel.navigateToFollowerRequests()
                        } label: {
                            Label {
                                HStack {
                                    Text("follow-requests").foregroundColor(.primary)
                                    Spacer()
                                    Text(verbatim: String(followRequestCount))
                                }
                            } icon: {
                                Image(systemName: "person.badge.plus")
                            }
                        }
                    }
                }
            }
            Section {
                NavigationLink(
                    destination: PreferencesView(viewModel: .init(identityContext: viewModel.identityContext))
                        .environmentObject(rootViewModel)) {
                    Label("secondary-navigation.preferences", systemImage: "gear")
                }
                NavigationLink(
                    destination: AboutInstanceLoader(
                        exploreViewModel: viewModel.exploreViewModel(),
                        navigationViewModel: viewModel
                    )
                ) {
                    Label {
                        Text(verbatim: aboutInstanceLocalizedTitle)
                    } icon: {
                        Image(systemName: "server.rack")
                    }
                }
                NavigationLink(
                    destination: AboutView(viewModel: viewModel)
                        .environmentObject(rootViewModel)) {
                    Label("secondary-navigation.about", systemImage: "info.circle")
                }
            }
        }
    }

    /// Return a string based on the instance's URI, or a fallback if it's not available for some reason.
    private var aboutInstanceLocalizedTitle: String {
        if let uri = viewModel.identityContext.identity.instance?.uri {
            return String.localizedStringWithFormat(
                NSLocalizedString("secondary-navigation.about-instance-%@", comment: ""),
                uri
            )
        } else {
            return NSLocalizedString("secondary-navigation.about-instance", comment: "")
        }
    }

    /// Exists entirely to wait for the instance view model to load.
    private struct AboutInstanceLoader: View {
        @ObservedObject var exploreViewModel: ExploreViewModel
        @ObservedObject var navigationViewModel: NavigationViewModel

        var body: some View {
            if let instanceViewModel = exploreViewModel.instanceViewModel {
                AboutInstanceView(
                    viewModel: instanceViewModel,
                    navigationViewModel: navigationViewModel
                )
            } else {
                EmptyView()
            }
        }
    }
}

#if DEBUG
import PreviewViewModels

struct SecondaryNavigationView_Previews: PreviewProvider {
    static var previews: some View {
        SecondaryNavigationView(viewModel: NavigationViewModel(identityContext: .preview, environment: .preview))
            .environmentObject(RootViewModel.preview)
    }
}
#endif
