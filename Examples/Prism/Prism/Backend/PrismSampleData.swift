import Foundation
import AnyChatUI

/// What the inbox shows about a person beyond `ChatSender`: their handle, whether they posted a
/// story, and whether they are online.
struct PrismProfile {
    let handle: String
    let hasStory: Bool
    let isActive: Bool
    let note: String?
}

enum PrismSampleData {
    struct Thread {
        let channel: ChatChannel
        let messages: [ChatMessage]
    }

    static let maya = ChatSender(id: "maya", name: "Maya Ortiz")
    static let jun = ChatSender(id: "jun", name: "Jun Park")
    static let leo = ChatSender(id: "leo", name: "Leo Brandt")
    static let ana = ChatSender(id: "ana", name: "Ana Souza")
    static let sol = ChatSender(id: "sol", name: "Sol Rivera")
    static let nora = ChatSender(id: "nora", name: "Nora Lind")
    static let kit = ChatSender(id: "kit", name: "Kit Moreau")

    static let people = [maya, jun, leo, ana, sol, nora, kit]

    static let profiles: [String: PrismProfile] = [
        PrismBackend.me.id: PrismProfile(handle: "you", hasStory: false, isActive: true, note: nil),
        maya.id: PrismProfile(handle: "maya.lens", hasStory: true, isActive: true, note: "chasing light ☀️"),
        jun.id: PrismProfile(handle: "jun.bakes", hasStory: true, isActive: false, note: "bread again 🍞"),
        leo.id: PrismProfile(handle: "leo_sketches", hasStory: false, isActive: true, note: nil),
        ana.id: PrismProfile(handle: "ana.vinyl", hasStory: true, isActive: false, note: "🎧 new vinyl"),
        sol.id: PrismProfile(handle: "sol.runs", hasStory: false, isActive: false, note: "10k sunday?"),
        nora.id: PrismProfile(handle: "nora.plants", hasStory: false, isActive: true, note: nil),
        kit.id: PrismProfile(handle: "kit.codes", hasStory: false, isActive: false, note: nil)
    ]

    static func profile(_ person: ChatSender) -> PrismProfile? {
        profiles[person.id]
    }

    static let replies = [
        "haha yes 😂",
        "omg wait",
        "100%",
        "send me more pics!!",
        "ok that's so good",
        "brb, call you later?",
        "🔥🔥🔥",
        "lol true"
    ]

    static func threads(now: Date) -> [Thread] {
        func ago(_ minutes: Double) -> Date { now.addingTimeInterval(-minutes * 60) }
        let me = PrismBackend.me
        var counter = 0
        func text(_ sender: ChatSender, _ minutes: Double, _ body: String, liked: [ChatSender] = [], read: Bool = true) -> ChatMessage {
            counter += 1
            var message = ChatMessage(
                id: "m\(counter)",
                sender: sender,
                createdAt: ago(minutes),
                content: .text(body),
                receipt: sender == me ? (read ? .read : .sent) : nil
            )
            if !liked.isEmpty {
                message.attributes[Likes.self] = Likes(userIDs: liked.map(\.id))
            }
            return message
        }
        func photo(_ sender: ChatSender, _ minutes: Double, _ name: String, caption: String = "") -> ChatMessage {
            counter += 1
            return ChatMessage(
                id: "m\(counter)",
                sender: sender,
                createdAt: ago(minutes),
                text: caption,
                attachments: [
                    ChatAttachment(
                        id: "a\(counter)",
                        kind: .image,
                        url: Bundle.main.url(forResource: name, withExtension: "jpg")!,
                        fileName: "\(name).jpg"
                    )
                ],
                receipt: sender == me ? .read : nil
            )
        }
        func thread(_ friend: ChatSender, unread: Int = 0, _ messages: [ChatMessage]) -> Thread {
            Thread(
                channel: ChatChannel(
                    id: "dm-\(friend.id)",
                    name: friend.name,
                    createdAt: ago(60 * 24 * 30),
                    members: [me, friend],
                    lastMessage: messages.last,
                    unreadMessageCount: unread,
                    canLeave: true
                ),
                messages: messages
            )
        }

        let trail = [me, maya, sol, nora]
        let trailMessages = [
            text(sol, 300, "who's in for saturday? 🥾"),
            text(nora, 296, "me! which trail"),
            text(sol, 295, "ridge loop, 9km, starts 8am"),
            text(me, 280, "count me in", liked: [sol, nora]),
            text(maya, 45, "bringing the good camera 📸"),
            text(sol, 41, "legend")
        ]

        return [
            thread(maya, unread: 2, [
                text(maya, 60 * 26, "are you still coming to the gallery thing?"),
                text(me, 60 * 25, "yes!! what time"),
                text(maya, 60 * 25, "7, I'll save you a spot"),
                photo(maya, 14, "landscape", caption: "scouting for tomorrow"),
                text(maya, 13, "the light up here is unreal")
            ]),
            Thread(
                channel: ChatChannel(
                    id: "group-trail",
                    name: "Weekend Trail Club 🥾",
                    createdAt: ago(60 * 24 * 60),
                    memberCount: trail.count,
                    members: trail,
                    lastMessage: trailMessages.last,
                    unreadMessageCount: 1,
                    canLeave: true
                ),
                messages: trailMessages
            ),
            thread(jun, [
                text(jun, 200, "made too much bread again"),
                text(jun, 199, "want a loaf?"),
                text(me, 180, "always yes", liked: [jun]),
                photo(jun, 178, "portrait"),
                text(me, 120, "that crumb 😍", read: false)
            ]),
            thread(leo, [
                text(leo, 60 * 30, "finished the poster"),
                text(me, 60 * 29, "can't wait to see it"),
                text(leo, 60 * 5, "sending tonight, promise")
            ]),
            thread(ana, [
                text(me, 60 * 50, "what was that record you played last week?"),
                text(ana, 60 * 49, "the blue one? I'll send you the name"),
                text(ana, 60 * 49, "it's a reissue, very rare", liked: [me])
            ]),
            thread(sol, [
                text(sol, 60 * 24 * 3, "pace was perfect today"),
                text(me, 60 * 24 * 3, "my legs disagree 😅")
            ]),
            thread(nora, [
                text(nora, 60 * 24 * 6, "your monstera needs water btw"),
                text(me, 60 * 24 * 6, "on it")
            ]),
            thread(kit, [
                text(kit, 60 * 24 * 9, "pushed the fix, lmk if it builds"),
                text(me, 60 * 24 * 9, "builds 🎉", liked: [kit])
            ])
        ]
    }
}
