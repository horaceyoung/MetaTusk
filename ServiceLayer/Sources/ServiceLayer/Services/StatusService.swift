// Copyright © 2020 Metabolist. All rights reserved.

import Combine
import DB
import Foundation
import Mastodon
import MastodonAPI

public struct StatusService {
    public let status: Status
    public let navigationService: NavigationService
    private let environment: AppEnvironment
    private let mastodonAPIClient: MastodonAPIClient
    private let contentDatabase: ContentDatabase

    init(environment: AppEnvironment,
         status: Status,
         mastodonAPIClient: MastodonAPIClient,
         contentDatabase: ContentDatabase) {
        self.status = status
        self.navigationService = NavigationService(
            environment: environment,
            mastodonAPIClient: mastodonAPIClient,
            contentDatabase: contentDatabase,
            status: status.displayStatus)
        self.environment = environment
        self.mastodonAPIClient = mastodonAPIClient
        self.contentDatabase = contentDatabase
    }
}

public extension StatusService {
    func toggleShowContent() -> AnyPublisher<Never, Error> {
        contentDatabase.toggleShowContent(id: status.displayStatus.id)
    }

    func toggleShowAttachments() -> AnyPublisher<Never, Error> {
        contentDatabase.toggleShowAttachments(id: status.displayStatus.id)
    }

    func toggleReblogged(identityId: Identity.Id?) -> AnyPublisher<Never, Error> {
        if let identityId = identityId {
            return request(identityId: identityId, endpointClosure: StatusEndpoint.reblog(id:))
        } else {
            return mastodonAPIClient.request(status.displayStatus.reblogged
                                                ? StatusEndpoint.unreblog(id: status.displayStatus.id)
                                                : StatusEndpoint.reblog(id: status.displayStatus.id))
                .flatMap(contentDatabase.insert(status:))
                .eraseToAnyPublisher()
        }
    }

    func toggleFavorited(identityId: Identity.Id?) -> AnyPublisher<Never, Error> {
        if let identityId = identityId {
            return request(identityId: identityId, endpointClosure: StatusEndpoint.favourite(id:))
        } else {
            return mastodonAPIClient.request(status.displayStatus.favourited
                                                ? StatusEndpoint.unfavourite(id: status.displayStatus.id)
                                                : StatusEndpoint.favourite(id: status.displayStatus.id))
                .flatMap(contentDatabase.insert(status:))
                .eraseToAnyPublisher()
        }
    }

    func toggleBookmarked() -> AnyPublisher<Never, Error> {
        mastodonAPIClient.request(status.displayStatus.bookmarked
                                    ? StatusEndpoint.unbookmark(id: status.displayStatus.id)
                                    : StatusEndpoint.bookmark(id: status.displayStatus.id))
            .flatMap(contentDatabase.insert(status:))
            .eraseToAnyPublisher()
    }

    func togglePinned() -> AnyPublisher<Never, Error> {
        mastodonAPIClient.request(status.displayStatus.pinned ?? false
                                    ? StatusEndpoint.unpin(id: status.displayStatus.id)
                                    : StatusEndpoint.pin(id: status.displayStatus.id))
            .flatMap(contentDatabase.insert(status:))
            .eraseToAnyPublisher()
    }

    func toggleMuted() -> AnyPublisher<Never, Error> {
        mastodonAPIClient.request(status.displayStatus.muted
                                    ? StatusEndpoint.unmute(id: status.displayStatus.id)
                                    : StatusEndpoint.mute(id: status.displayStatus.id))
            .flatMap(contentDatabase.insert(status:))
            .eraseToAnyPublisher()
    }

    func delete() -> AnyPublisher<Status, Error> {
        mastodonAPIClient.request(StatusEndpoint.delete(id: status.displayStatus.id))
            .flatMap { status in contentDatabase.delete(id: status.id).collect().map { _ in status } }
            .eraseToAnyPublisher()
    }

    func deleteAndRedraft() -> AnyPublisher<Status, Error> {
        return mastodonAPIClient.request(StatusEndpoint.delete(id: status.displayStatus.id))
            .flatMap { status in contentDatabase.delete(id: status.id).collect().map { _ in status } }
            .eraseToAnyPublisher()
    }

    /// Called when editing a status to fetch the raw source text.
    func withSource() -> AnyPublisher<Status, Error> {
        guard status.displayStatus.text == nil else {
            // Either we're using a non-standard backend that always provides this,
            // or we already had it from a previous edit attempt.
            return Just(status.displayStatus)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }

        // We normally won't have this from Mastodon proper, since it's only set
        // on the status returned from a delete, so we have to ask for it.
        return mastodonAPIClient.request(StatusSourceEndpoint.source(id: status.displayStatus.id))
            .andAlso { contentDatabase.update(id: status.displayStatus.id, source: $0) }
            .map { status.displayStatus.with(source: $0) }
            .eraseToAnyPublisher()
    }

    /// Retrieve the edit history.
    func history() -> AnyPublisher<[StatusEdit], Error> {
        // TODO: (Vyr) use DB as cache
        mastodonAPIClient.request(StatusEditsEndpoint.history(id: status.displayStatus.id))
    }

    /// Re-fetch the status being replied to, but we're okay with it failing,
    /// in which case it will succeed but return nil.
    func inReplyTo() -> AnyPublisher<Self?, Error> {
        if let inReplyToId = status.displayStatus.inReplyToId {
            return mastodonAPIClient.request(StatusEndpoint.status(id: inReplyToId))
                .map {
                    Self(environment: environment,
                         status: $0,
                         mastodonAPIClient: mastodonAPIClient,
                         contentDatabase: contentDatabase) as Self?
                }
                .replaceError(with: nil)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        } else {
            return Just(nil)
                .setFailureType(to: Error.self)
                .eraseToAnyPublisher()
        }
    }

    func rebloggedByService() -> AccountListService {
        AccountListService(
            endpoint: .rebloggedBy(id: status.id),
            environment: environment,
            mastodonAPIClient: mastodonAPIClient,
            contentDatabase: contentDatabase,
            titleComponents: ["account-list.title.reblogged-by"]
        )
    }

    func favoritedByService() -> AccountListService {
        AccountListService(
            endpoint: .favouritedBy(id: status.id),
            environment: environment,
            mastodonAPIClient: mastodonAPIClient,
            contentDatabase: contentDatabase,
            titleComponents: ["account-list.title.favourited-by"]
        )
    }

    func vote(selectedOptions: Set<Int>) -> AnyPublisher<Never, Error> {
        guard let poll = status.displayStatus.poll else { return Empty().eraseToAnyPublisher() }

        return mastodonAPIClient.request(PollEndpoint.votes(id: poll.id, choices: Array(selectedOptions)))
            .flatMap { contentDatabase.update(id: status.displayStatus.id, poll: $0) }
            .eraseToAnyPublisher()
    }

    func refreshPoll() -> AnyPublisher<Never, Error> {
        guard let poll = status.displayStatus.poll else { return Empty().eraseToAnyPublisher() }

        return mastodonAPIClient.request(PollEndpoint.poll(id: poll.id))
            .flatMap { contentDatabase.update(id: status.displayStatus.id, poll: $0) }
            .eraseToAnyPublisher()
    }

    func asIdentity(id: Identity.Id) -> AnyPublisher<Self, Error> {
        fetchAs(identityId: id).tryMap {
            Self(environment: environment,
                 status: $0,
                 mastodonAPIClient: try MastodonAPIClient.forIdentity(id: id, environment: environment),
                 contentDatabase: try ContentDatabase(
                    id: id,
                    useHomeTimelineLastReadId: true,
                    inMemory: environment.inMemoryContent,
                    appGroup: AppEnvironment.appGroup,
                    keychain: environment.keychain)) }
            .eraseToAnyPublisher()
    }
}

private extension StatusService {
    func fetchAs(identityId: Identity.Id) -> AnyPublisher<Status, Error> {
        let client: MastodonAPIClient

        do {
            client = try MastodonAPIClient.forIdentity(id: identityId, environment: environment)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }

        return client
            .request(ResultsEndpoint.search(.init(query: status.displayStatus.uri, limit: 1)))
            .tryMap {
                guard let status = $0.statuses.first else { throw APIError.unableToFetchRemoteStatus }

                return status
            }
            .eraseToAnyPublisher()
    }

    func request(identityId: Identity.Id,
                 endpointClosure: @escaping (Status.Id) -> StatusEndpoint) -> AnyPublisher<Never, Error> {
        let client: MastodonAPIClient

        do {
            client = try MastodonAPIClient.forIdentity(id: identityId, environment: environment)
        } catch {
            return Fail(error: error).eraseToAnyPublisher()
        }

        return fetchAs(identityId: identityId)
            .flatMap { client.request(endpointClosure($0.id)) }
            .flatMap { _ in mastodonAPIClient.request(StatusEndpoint.status(id: status.displayStatus.id)) }
            .flatMap(contentDatabase.insert(status:))
            .eraseToAnyPublisher()
    }
}
