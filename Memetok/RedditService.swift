import Foundation

enum RedditError: Error {
    case invalidURL
    case invalidResponse
    case networkError(Error)
    case decodingError(Error)
}

struct RedditPost: Codable {
    let id: String
    let title: String
    let url: String
    let subreddit: String
    let score: Int
    let upvoteRatio: Double
    let createdUtc: Double
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case url
        case subreddit
        case score
        case upvoteRatio = "upvote_ratio"
        case createdUtc = "created_utc"
    }
}

class RedditService {
    private let session: URLSession
    private let baseURL = "https://www.reddit.com"
    
    // Categorized subreddits for better content organization
    private let subredditsByCategory: [MemeCategory: [String]] = [
        .entertainment: [
            // Bollywood specific
            "BollyBlindsNGossip",
            "bollywoodmemes",
            "bollywood",
            "IndianCinema",
            "BollywoodRealism",
            // General entertainment
            "SaimanSays",
            "IndianDankMemes",
            "desimemes"
        ],
        .tech: [
            "ProgrammerHumor",
            "programmerreactions",
            "coding_memes",
            "programmingmemes",
            "techhumor",
            "softwaregore",
            "developersIndia",
            "IndianTechnology"
        ],
        .sports: [
            "CricketShitpost",
            "cricketmemes",
            "Cricket",
            "IndianSports",
            "indiansports"
        ],
        .politics: [
            "indiameme",
            "indianpoliticalmemes",
            "dankinindia"
        ]
    ]
    
    // Keywords for better categorization
    private let categoryKeywords: [MemeCategory: Set<String>] = [
        .sports: [
            "icc", "champions trophy", "cricket", "india", "bangladesh", "pakistan",
            "kohli", "rohit", "dhoni", "worldcup", "match", "batting", "bowling",
            "wicket", "run", "score", "ipl", "bcci", "stadium"
        ],
        .entertainment: [
            "movie", "bollywood", "actor", "film", "cinema", "song", "dance",
            "shah rukh", "salman", "aamir", "deepika", "ranveer", "netflix"
        ],
        .tech: [
            "coding", "programming", "software", "app", "startup", "ai", "chatgpt",
            "computer", "developer", "tech", "google", "apple", "android"
        ],
        .politics: [
            "government", "minister", "election", "party", "congress", "bjp",
            "parliament", "modi", "policy", "vote"
        ]
    ]
    
    init(session: URLSession = .shared) {
        self.session = session
    }
    
    func analyzeTrending() async throws -> [String: [RedditPost]] {
        var trendingBySubreddit: [String: [RedditPost]] = [:]
        var seenMemes = Set<String>() // Track unique memes by URL
        
        // First, try to fetch ICC Champions Trophy specific content
        if let champsTrophyPosts = try? await fetchChampionsTrophyMemes() {
            for post in champsTrophyPosts {
                if !seenMemes.contains(post.url) {
                    seenMemes.insert(post.url)
                    trendingBySubreddit["ICC_Champions_Trophy"] = (trendingBySubreddit["ICC_Champions_Trophy"] ?? []) + [post]
                }
            }
        }
        
        // Then fetch from categorized subreddits
        for (_, subreddits) in subredditsByCategory {
            for subreddit in subreddits {
                if let posts = try? await fetchTrendingMemes(from: subreddit, limit: 25) {
                    let uniquePosts = posts.filter { !seenMemes.contains($0.url) }
                    uniquePosts.forEach { seenMemes.insert($0.url) }
                    if !uniquePosts.isEmpty {
                        trendingBySubreddit[subreddit] = uniquePosts
                    }
                }
            }
        }
        
        return trendingBySubreddit
    }
    
    private func fetchChampionsTrophyMemes() async throws -> [RedditPost] {
        // Search multiple cricket subreddits with Champions Trophy specific queries
        let queries = [
            "champions+trophy",
            "india+bangladesh+match",
            "icc+tournament",
            "cricket+worldcup"
        ]
        
        var allPosts: [RedditPost] = []
        let subreddits = subredditsByCategory[.sports] ?? []
        
        for subreddit in subreddits {
            for query in queries {
                let searchURL = URL(string: "\(baseURL)/r/\(subreddit)/search.json?q=\(query)&sort=new&limit=25")!
                if let posts = try? await fetchPosts(from: searchURL) {
                    allPosts.append(contentsOf: posts)
                }
            }
        }
        
        // Filter for recent and relevant posts
        return allPosts
            .filter { isValidMemePost($0) && isRecentPost($0) }
            .sorted { $0.score > $1.score }
    }
    
    private func isRecentPost(_ post: RedditPost) -> Bool {
        let currentTime = Date().timeIntervalSince1970
        let postAge = currentTime - post.createdUtc
        return postAge < (5 * 24 * 60 * 60) // Within last 5 days
    }
    
    private func determineCategory(_ post: RedditPost) -> MemeCategory {
        let title = post.title.lowercased()
        let subreddit = post.subreddit.lowercased()
        
        // First check if the subreddit directly matches a category
        for (category, subreddits) in subredditsByCategory {
            if subreddits.contains(where: { subreddit.contains($0.lowercased()) }) {
                return category
            }
        }
        
        // Then check title keywords
        let bollywoodKeywords = ["bollywood", "hindi film", "hindi movie", "srk", "salman", "aamir", 
                                "deepika", "ranveer", "karan johar", "dharma", "alia", "ranbir"]
        let techKeywords = ["programming", "coding", "developer", "software", "computer", "tech", 
                           "ai", "artificial intelligence", "machine learning", "code"]
        let sportsKeywords = ["cricket", "ipl", "bcci", "match", "sport", "game", "player", 
                             "stadium", "tournament", "world cup"]
        let politicsKeywords = ["politics", "government", "minister", "modi", "congress", "bjp", 
                               "parliament", "election"]
        
        if bollywoodKeywords.contains(where: { title.contains($0) }) {
            return .entertainment
        }
        if techKeywords.contains(where: { title.contains($0) }) {
            return .tech
        }
        if sportsKeywords.contains(where: { title.contains($0) }) {
            return .sports
        }
        if politicsKeywords.contains(where: { title.contains($0) }) {
            return .politics
        }
        
        // Default to entertainment for Indian meme subreddits
        if subreddit.contains("indian") || subreddit.contains("desi") {
            return .entertainment
        }
        
        return .other
    }
    
    func fetchTrendingMemes(from subreddit: String, limit: Int = 25) async throws -> [RedditPost] {
        // First try to fetch hot posts
        let hotURL = URL(string: "\(baseURL)/r/\(subreddit)/hot.json?limit=\(limit)")!
        let newURL = URL(string: "\(baseURL)/r/\(subreddit)/new.json?limit=\(limit)")!
        let topURL = URL(string: "\(baseURL)/r/\(subreddit)/top.json?t=day&limit=\(limit)")!
        
        async let hotPosts = fetchPosts(from: hotURL)
        async let newPosts = fetchPosts(from: newURL)
        async let topPosts = fetchPosts(from: topURL)
        
        let (hot, new, top) = try await (hotPosts, newPosts, topPosts)
        
        // Combine and filter for recent posts
        var allPosts = (hot + new + top).filter { isRecentPost($0) }
        
        // Remove duplicates using URL, title similarity, and image comparison
        var seen = Set<String>()
        var seenTitles = Set<String>()
        allPosts = allPosts.filter { post in
            // Check for duplicate URLs
            let normalizedURL = post.url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !seen.contains(normalizedURL) else { return false }
            seen.insert(normalizedURL)
            
            // Check for similar titles
            let normalizedTitle = post.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            let titleWords = Set(normalizedTitle.split(separator: " ").map(String.init))
            
            for existingTitle in seenTitles {
                let existingWords = Set(existingTitle.split(separator: " ").map(String.init))
                let commonWords = titleWords.intersection(existingWords)
                
                // If more than 70% words are common, consider it a duplicate
                if !titleWords.isEmpty && !existingWords.isEmpty {
                    let similarity = Double(commonWords.count) / Double(max(titleWords.count, existingWords.count))
                    if similarity > 0.7 {
                        return false
                    }
                }
            }
            seenTitles.insert(normalizedTitle)
            
            return isValidMemePost(post)
        }
        
        // Sort by trending score (combination of score, upvote ratio, and recency)
        allPosts.sort { post1, post2 in
            let age1 = Date().timeIntervalSince1970 - post1.createdUtc
            let age2 = Date().timeIntervalSince1970 - post2.createdUtc
            
            let recencyBonus1 = 1.0 / (age1 / 3600 + 1) // Bonus for newer posts (in hours)
            let recencyBonus2 = 1.0 / (age2 / 3600 + 1)
            
            let score1 = Double(post1.score) * post1.upvoteRatio * recencyBonus1
            let score2 = Double(post2.score) * post2.upvoteRatio * recencyBonus2
            
            return score1 > score2
        }
        
        return Array(allPosts.prefix(limit))
    }
    
    private func fetchPosts(from url: URL) async throws -> [RedditPost] {
        let (data, response) = try await session.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw RedditError.invalidResponse
        }
        
        let decoder = JSONDecoder()
        let listing = try decoder.decode(RedditListing.self, from: data)
        return listing.data.children.map { $0.data }
    }
    
    private func isValidMemePost(_ post: RedditPost) -> Bool {
        // Check if the URL points to an image
        let imageExtensions = [".jpg", ".jpeg", ".png", ".gif"]
        let hasImageExtension = imageExtensions.contains { post.url.lowercased().hasSuffix($0) }
        
        // Check for common image hosting domains
        let imageHosts = ["i.redd.it", "i.imgur.com", "imgur.com"]
        let isImageHost = imageHosts.contains { post.url.contains($0) }
        
        return hasImageExtension || isImageHost
    }
}

// Supporting structures for JSON decoding
struct RedditListing: Codable {
    let data: RedditListingData
}

struct RedditListingData: Codable {
    let children: [RedditChild]
}

struct RedditChild: Codable {
    let data: RedditPost
}
