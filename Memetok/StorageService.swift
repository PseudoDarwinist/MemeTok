import Foundation
import SQLite3

class StorageService {
    private var db: OpaquePointer?
    
    init() {
        setupDatabase()
    }
    
    private func setupDatabase() {
        let fileURL = try! FileManager.default
            .url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: false)
            .appendingPathComponent("memes.sqlite")
        
        if sqlite3_open(fileURL.path, &db) != SQLITE_OK {
            print("Error opening database")
            return
        }
        
        createTables()
    }
    
    private func createTables() {
        let createTopicsTable = """
        CREATE TABLE IF NOT EXISTS topics (
            id TEXT PRIMARY KEY,
            title TEXT NOT NULL,
            category TEXT NOT NULL,
            subcategory_id TEXT,
            created_at INTEGER NOT NULL,
            trending_score REAL NOT NULL,
            is_active INTEGER NOT NULL
        );
        """
        
        let createMemesTable = """
        CREATE TABLE IF NOT EXISTS memes (
            id TEXT PRIMARY KEY,
            reddit_id TEXT NOT NULL,
            image_url TEXT NOT NULL,
            title TEXT NOT NULL,
            upvotes INTEGER NOT NULL,
            upvote_ratio REAL NOT NULL,
            source_url TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            topic_id TEXT,
            subreddit TEXT NOT NULL,
            FOREIGN KEY(topic_id) REFERENCES topics(id)
        );
        """
        
        executeSQLStatement(createTopicsTable)
        executeSQLStatement(createMemesTable)
    }
    
    private func executeSQLStatement(_ sql: String) {
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK {
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error creating table")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func saveMeme(_ meme: RedditPost, topicId: String?) {
        let insertSQL = """
        INSERT OR REPLACE INTO memes (
            id, reddit_id, image_url, title, upvotes, 
            upvote_ratio, source_url, created_at, topic_id, subreddit
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            let id = UUID().uuidString
            sqlite3_bind_text(statement, 1, (id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (meme.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (meme.url as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 4, (meme.title as NSString).utf8String, -1, nil)
            sqlite3_bind_int(statement, 5, Int32(meme.score))
            sqlite3_bind_double(statement, 6, meme.upvoteRatio)
            sqlite3_bind_text(statement, 7, (meme.url as NSString).utf8String, -1, nil)
            sqlite3_bind_int64(statement, 8, Int64(meme.createdUtc))
            if let topicId = topicId {
                sqlite3_bind_text(statement, 9, (topicId as NSString).utf8String, -1, nil)
            }
            sqlite3_bind_text(statement, 10, (meme.subreddit as NSString).utf8String, -1, nil)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error saving meme")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func saveTopic(_ topic: MemeTopic) {
        let insertSQL = """
        INSERT OR REPLACE INTO topics (
            id, title, category, subcategory_id, created_at, 
            trending_score, is_active
        ) VALUES (?, ?, ?, ?, ?, ?, ?);
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, insertSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (topic.id as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 2, (topic.title as NSString).utf8String, -1, nil)
            sqlite3_bind_text(statement, 3, (topic.category.rawValue as NSString).utf8String, -1, nil)
            if let subcategoryId = topic.subcategoryId {
                sqlite3_bind_text(statement, 4, (subcategoryId as NSString).utf8String, -1, nil)
            } else {
                sqlite3_bind_null(statement, 4)
            }
            sqlite3_bind_int64(statement, 5, Int64(topic.createdAt.timeIntervalSince1970))
            sqlite3_bind_double(statement, 6, topic.trendingScore)
            sqlite3_bind_int(statement, 7, topic.isActive ? 1 : 0)
            
            if sqlite3_step(statement) != SQLITE_DONE {
                print("Error saving topic")
            }
        }
        sqlite3_finalize(statement)
    }
    
    func getTopics(category: MemeCategory? = nil, subcategoryId: String? = nil, isActive: Bool? = nil) -> [MemeTopic] {
        var topics: [MemeTopic] = []
        var whereClause = ""
        var queryParams: [String] = []
        
        if let category = category {
            whereClause += "category = ? "
            queryParams.append(category.rawValue)
        }
        
        if let subcategoryId = subcategoryId {
            if !whereClause.isEmpty {
                whereClause += "AND "
            }
            whereClause += "subcategory_id = ? "
            queryParams.append(subcategoryId)
        }
        
        if let isActive = isActive {
            if !whereClause.isEmpty {
                whereClause += "AND "
            }
            whereClause += "is_active = ? "
            queryParams.append(isActive ? "1" : "0")
        }
        
        let selectSQL = """
        SELECT id, title, category, subcategory_id, created_at, trending_score, is_active 
        FROM topics
        \(whereClause.isEmpty ? "" : "WHERE \(whereClause)")
        ORDER BY trending_score DESC;
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            for (index, param) in queryParams.enumerated() {
                sqlite3_bind_text(statement, Int32(index + 1), (param as NSString).utf8String, -1, nil)
            }
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let categoryStr = String(cString: sqlite3_column_text(statement, 2))
                let subcategoryId = sqlite3_column_text(statement, 3).map { String(cString: $0) }
                let createdAt = Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 4)))
                let trendingScore = sqlite3_column_double(statement, 5)
                let isActive = sqlite3_column_int(statement, 6) != 0
                
                let category = MemeCategory(rawValue: categoryStr) ?? .other
                
                let topic = MemeTopic(
                    id: id,
                    title: title,
                    category: category,
                    subcategoryId: subcategoryId,
                    createdAt: createdAt,
                    trendingScore: trendingScore,
                    isActive: isActive
                )
                topics.append(topic)
            }
        }
        sqlite3_finalize(statement)
        return topics
    }
    
    func getMemesForTopic(_ topicId: String) -> [RedditPost] {
        var memes: [RedditPost] = []
        let selectSQL = """
        SELECT m.reddit_id, m.title, m.image_url, m.subreddit, m.upvotes, m.upvote_ratio, m.created_at
        FROM memes m
        WHERE m.topic_id = ?
        ORDER BY m.created_at DESC;
        """
        
        var statement: OpaquePointer?
        if sqlite3_prepare_v2(db, selectSQL, -1, &statement, nil) == SQLITE_OK {
            sqlite3_bind_text(statement, 1, (topicId as NSString).utf8String, -1, nil)
            
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = String(cString: sqlite3_column_text(statement, 0))
                let title = String(cString: sqlite3_column_text(statement, 1))
                let url = String(cString: sqlite3_column_text(statement, 2))
                let subreddit = String(cString: sqlite3_column_text(statement, 3))
                let upvotes = Int(sqlite3_column_int(statement, 4))
                let upvoteRatio = sqlite3_column_double(statement, 5)
                let createdUtc = Double(sqlite3_column_int64(statement, 6))
                
                let meme = RedditPost(
                    id: id,
                    title: title,
                    url: url,
                    subreddit: subreddit,
                    score: upvotes,
                    upvoteRatio: upvoteRatio,
                    createdUtc: createdUtc
                )
                memes.append(meme)
            }
        }
        sqlite3_finalize(statement)
        return memes
    }
}
