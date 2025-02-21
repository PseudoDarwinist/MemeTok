import Foundation
import NaturalLanguage

enum MemeCategory: String, CaseIterable {
    case sports = "Sports"
    case politics = "Politics"
    case entertainment = "Entertainment"
    case tech = "Tech"
    case other = "Other"
    
    var subcategories: [MemeSubcategory] {
        switch self {
        case .sports:
            return [
                MemeSubcategory(id: "cricket", name: "Cricket", keywords: ["cricket", "ipl", "bcci", "test match", "t20"]),
                MemeSubcategory(id: "soccer", name: "Soccer", keywords: ["soccer", "football", "fifa", "premier league", "champions league"]),
                MemeSubcategory(id: "basketball", name: "Basketball", keywords: ["nba", "basketball", "lebron", "bulls", "lakers"]),
                MemeSubcategory(id: "formula1", name: "Formula 1", keywords: ["f1", "formula 1", "racing", "ferrari", "mercedes"]),
                MemeSubcategory(id: "esports", name: "Esports", keywords: ["esports", "competitive gaming", "tournament", "league"])
            ]
        case .tech:
            return [
                MemeSubcategory(id: "programming", name: "Programming", keywords: [
                    "programming", "coding", "developer", "software", "bug", "code",
                    "compiler", "debugging", "algorithm", "git", "stack overflow",
                    "python", "java", "javascript", "css", "html", "react", "angular",
                    "exam", "student", "cheating", "study", "homework", "assignment"
                ]),
                MemeSubcategory(id: "ai_ml", name: "AI & ML", keywords: [
                    "ai", "artificial intelligence", "machine learning", "chatgpt", "deep learning",
                    "neural network", "data science", "model", "training", "dataset"
                ]),
                MemeSubcategory(id: "elon", name: "Elon Musk", keywords: [
                    "elon", "musk", "tesla", "spacex", "twitter", "x", "starship",
                    "boring company", "neuralink", "cybertruck"
                ]),
                MemeSubcategory(id: "tech_companies", name: "Tech Companies", keywords: [
                    "google", "apple", "microsoft", "meta", "facebook", "amazon", "aws",
                    "netflix", "startup", "silicon valley", "tech company"
                ]),
                MemeSubcategory(id: "gaming_tech", name: "Gaming & Hardware", keywords: [
                    "gpu", "cpu", "gaming pc", "console", "playstation", "xbox",
                    "nvidia", "amd", "intel", "hardware", "ram", "ssd"
                ]),
                MemeSubcategory(id: "education", name: "Education", keywords: [
                    "exam", "student", "study", "homework", "assignment",
                    "college", "university", "school", "cheating", "grade",
                    "professor", "teacher", "lecture", "class", "semester",
                    "finals", "midterm", "quiz", "test", "project",
                    "deadline", "submission", "lab", "tutorial", "course"
                ])
            ]
        case .entertainment:
            return [
                MemeSubcategory(id: "hollywood", name: "Hollywood", keywords: ["hollywood", "marvel", "dc", "disney", "warner"]),
                MemeSubcategory(id: "bollywood", name: "Bollywood", keywords: ["bollywood", "hindi", "mumbai", "shah rukh", "salman"]),
                MemeSubcategory(id: "anime", name: "Anime", keywords: ["anime", "manga", "japan", "otaku", "naruto"]),
                MemeSubcategory(id: "gaming", name: "Gaming", keywords: ["gaming", "playstation", "xbox", "nintendo", "steam"]),
                MemeSubcategory(id: "streaming", name: "Streaming", keywords: ["netflix", "prime", "disney+", "hulu", "streaming"])
            ]
        case .politics:
            return [
                MemeSubcategory(id: "us_politics", name: "US Politics", keywords: ["biden", "trump", "democrat", "republican", "congress"]),
                MemeSubcategory(id: "world_politics", name: "World Politics", keywords: ["un", "eu", "nato", "summit", "international"]),
                MemeSubcategory(id: "elections", name: "Elections", keywords: ["election", "vote", "campaign", "ballot", "polling"]),
                MemeSubcategory(id: "policy", name: "Policy", keywords: ["policy", "law", "regulation", "reform", "bill"])
            ]
        case .other:
            return []
        }
    }
}

struct MemeSubcategory {
    let id: String
    let name: String
    let keywords: Set<String>
}

struct MemeTopic {
    let id: String
    let title: String
    let category: MemeCategory
    let subcategoryId: String?
    let createdAt: Date
    let trendingScore: Double
    var isActive: Bool
    
    var asDictionary: [String: Any] {
        var dict = [
            "id": id,
            "title": title,
            "category": category.rawValue,
            "created_at": createdAt.timeIntervalSince1970,
            "trending_score": trendingScore,
            "is_active": isActive ? 1 : 0
        ] as [String: Any]
        
        if let subcategoryId = subcategoryId {
            dict["subcategory_id"] = subcategoryId
        }
        
        return dict
    }
}

class TopicAnalysisService {
    private let tagger = NLTagger(tagSchemes: [.nameType, .lexicalClass])
    private let storageService: StorageService
    
    init(storageService: StorageService) {
        self.storageService = storageService
    }
    
    func analyzeMeme(_ post: RedditPost) -> MemeTopic {
        let textToAnalyze = post.title
        tagger.string = textToAnalyze
        
        var keyTerms: [String] = []
        tagger.enumerateTags(in: textToAnalyze.startIndex..<textToAnalyze.endIndex,
                            unit: .word,
                            scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                let term = String(textToAnalyze[tokenRange])
                keyTerms.append(term)
            }
            return true
        }
        
        let (category, subcategoryId) = determineCategory(from: keyTerms, title: post.title)
        
        let topic = MemeTopic(
            id: UUID().uuidString,
            title: generateTopicTitle(from: keyTerms, originalTitle: post.title),
            category: category,
            subcategoryId: subcategoryId,
            createdAt: Date(timeIntervalSince1970: post.createdUtc),
            trendingScore: calculateTrendingScore(post),
            isActive: true
        )
        
        storageService.saveTopic(topic)
        return topic
    }
    
    private func determineCategory(from terms: [String], title: String) -> (MemeCategory, String?) {
        let lowercaseTitle = title.lowercased()
        
        // Check for education content first
        let educationKeywords = ["exam", "student", "study", "homework", "assignment", 
                               "college", "university", "school", "cheating", "grade",
                               "professor", "teacher", "lecture", "class"]
        if educationKeywords.contains(where: { lowercaseTitle.contains($0) }) {
            return (.tech, "education") // Now categorize education memes under education subcategory
        }
        
        // First check for student/education related content
        let educationKeywordsFull = ["exam", "student", "study", "homework", "assignment", 
                                    "college", "university", "school", "cheating", "grade",
                                    "professor", "teacher", "lecture", "class"]
        if educationKeywordsFull.contains(where: { lowercaseTitle.contains($0) }) {
            return (.tech, "programming") // Categorize education memes under programming
        }
        
        // Check each category and its subcategories
        for category in MemeCategory.allCases {
            for subcategory in category.subcategories {
                // Check for exact keyword matches
                if subcategory.keywords.contains(where: { lowercaseTitle.contains($0) }) {
                    return (category, subcategory.id)
                }
                
                // Check for related terms
                let titleWords = Set(lowercaseTitle.split(separator: " ").map(String.init))
                let keywordMatches = subcategory.keywords.filter { keyword in
                    titleWords.contains(keyword) || 
                    titleWords.contains(where: { $0.contains(keyword) })
                }
                
                if !keywordMatches.isEmpty {
                    return (category, subcategory.id)
                }
            }
        }
        
        // If no subcategory match, try to match just the category using more specific keywords
        let categoryKeywords: [MemeCategory: Set<String>] = [
            .sports: [
                "cricket", "ipl", "bcci", "match", "game", "player", "team", "sport",
                "tournament", "stadium", "ball", "bat", "wicket", "over", "run"
            ],
            .tech: [
                "programming", "code", "developer", "software", "computer", "tech",
                "ai", "machine learning", "data", "algorithm", "bug", "feature"
            ],
            .entertainment: [
                "movie", "film", "actor", "actress", "director", "cinema", "bollywood",
                "hollywood", "show", "series", "episode", "season", "trailer"
            ],
            .politics: [
                "politics", "government", "minister", "party", "election", "vote",
                "campaign", "policy", "parliament", "congress", "bjp", "modi"
            ]
        ]
        
        for (category, keywords) in categoryKeywords {
            if keywords.contains(where: { lowercaseTitle.contains($0) }) {
                return (category, nil)
            }
        }
        
        // Use NLP for better categorization
        tagger.string = lowercaseTitle
        var entities: Set<String> = []
        
        tagger.enumerateTags(in: lowercaseTitle.startIndex..<lowercaseTitle.endIndex,
                            unit: .word,
                            scheme: .nameType) { tag, tokenRange in
            if let tag = tag {
                entities.insert(String(lowercaseTitle[tokenRange]).lowercased())
            }
            return true
        }
        
        // Check entities against category keywords
        for (category, keywords) in categoryKeywords {
            if !entities.intersection(keywords).isEmpty {
                return (category, nil)
            }
        }
        
        return (.other, nil)
    }
    
    private func generateTopicTitle(from terms: [String], originalTitle: String) -> String {
        return originalTitle
    }
    
    private func calculateTrendingScore(_ post: RedditPost) -> Double {
        return Double(post.score) * post.upvoteRatio
    }
} 