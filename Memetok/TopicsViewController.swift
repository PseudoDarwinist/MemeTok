import UIKit

class TopicsViewController: UIViewController {
    private let storageService = StorageService()
    private let topicAnalysisService: TopicAnalysisService
    private var selectedCategory: MemeCategory = .tech
    private var subcategories: [MemeSubcategory] = []
    private var topicsBySubcategory: [String: [MemeTopic]] = [:]
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 8
        layout.minimumLineSpacing = 8
        layout.sectionInset = UIEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .systemBackground
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.register(LiveTileCollectionViewCell.self, forCellWithReuseIdentifier: LiveTileCollectionViewCell.identifier)
        return collectionView
    }()
    
    private lazy var categorySegmentedControl: UISegmentedControl = {
        let items = MemeCategory.allCases.filter { $0 != .other }.map { $0.rawValue }
        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 3 // Tech by default
        control.addTarget(self, action: #selector(categoryChanged), for: .valueChanged)
        return control
    }()
    
    init() {
        self.topicAnalysisService = TopicAnalysisService(storageService: storageService)
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        loadTopics()
    }
    
    private func setupUI() {
        title = "Trending Topics"
        view.backgroundColor = .systemBackground
        
        view.addSubview(categorySegmentedControl)
        view.addSubview(collectionView)
        
        categorySegmentedControl.translatesAutoresizingMaskIntoConstraints = false
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            categorySegmentedControl.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 8),
            categorySegmentedControl.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
            categorySegmentedControl.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
            
            collectionView.topAnchor.constraint(equalTo: categorySegmentedControl.bottomAnchor, constant: 8),
            collectionView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            collectionView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }
    
    @objc private func categoryChanged(_ sender: UISegmentedControl) {
        selectedCategory = MemeCategory.allCases.filter { $0 != .other }[sender.selectedSegmentIndex]
        loadTopics()
    }
    
    private func loadTopics() {
        // Get subcategories for selected category
        subcategories = selectedCategory.subcategories
        
        // Get all topics for the category
        let topics = storageService.getTopics(category: selectedCategory, isActive: true)
        
        // Group topics by subcategory
        topicsBySubcategory = Dictionary(grouping: topics) { topic in
            topic.subcategoryId ?? "other"
        }
        
        if topics.isEmpty {
            collectionView.backgroundView = createEmptyStateView()
        } else {
            collectionView.backgroundView = nil
        }
        
        collectionView.reloadData()
    }
    
    private func createEmptyStateView() -> UIView {
        let view = UIView()
        let label = UILabel()
        label.text = "No memes found for this category"
        label.textAlignment = .center
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }
    
    private func color(for index: Int) -> UIColor {
        let colors: [UIColor] = [
            .systemBlue,
            .systemGreen,
            .systemRed,
            .systemPurple,
            .systemOrange,
            .systemTeal,
            .systemIndigo,
            .systemPink
        ]
        return colors[index % colors.count]
    }
}

extension TopicsViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return subcategories.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: LiveTileCollectionViewCell.identifier, for: indexPath) as? LiveTileCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        let subcategory = subcategories[indexPath.item]
        let topics = topicsBySubcategory[subcategory.id] ?? []
        let count = topics.count // This is already an Int
        cell.configure(with: subcategory, count: count, color: color(for: indexPath.item))
        
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 8
        let availableWidth = collectionView.bounds.width - (padding * 3) // 3 paddings for 2 columns
        let width = availableWidth / 2
        return CGSize(width: width, height: width)
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let subcategory = subcategories[indexPath.item]
        let topics = topicsBySubcategory[subcategory.id] ?? []
        
        // Create a new MemesViewController with all memes from the topics
        let memesVC = MemesViewController()
        memesVC.title = subcategory.name
        
        // Get all memes for this subcategory and remove duplicates
        var allMemes: [RedditPost] = []
        var seenURLs = Set<String>()
        var seenTitles = Set<String>()
        
        for topic in topics {
            let memes = storageService.getMemesForTopic(topic.id)
            for meme in memes {
                // Normalize URL and title
                let normalizedURL = meme.url.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                let normalizedTitle = meme.title.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                
                // Skip if we've seen this URL
                guard !seenURLs.contains(normalizedURL) else { continue }
                
                // Check for similar titles
                let titleWords = Set(normalizedTitle.split(separator: " ").map(String.init))
                var isDuplicate = false
                
                for existingTitle in seenTitles {
                    let existingWords = Set(existingTitle.split(separator: " ").map(String.init))
                    let commonWords = titleWords.intersection(existingWords)
                    
                    // If more than 70% words are common, consider it a duplicate
                    if !titleWords.isEmpty && !existingWords.isEmpty {
                        let similarity = Double(commonWords.count) / Double(max(titleWords.count, existingWords.count))
                        if similarity > 0.7 {
                            isDuplicate = true
                            break
                        }
                    }
                }
                
                if !isDuplicate {
                    allMemes.append(meme)
                    seenURLs.insert(normalizedURL)
                    seenTitles.insert(normalizedTitle)
                }
            }
        }
        
        // Sort by trending score and recency
        allMemes.sort { first, second in
            let age1 = Date().timeIntervalSince1970 - first.createdUtc
            let age2 = Date().timeIntervalSince1970 - second.createdUtc
            
            let recencyBonus1 = 1.0 / (age1 / 3600 + 1) // Bonus for newer posts (in hours)
            let recencyBonus2 = 1.0 / (age2 / 3600 + 1)
            
            let score1 = Double(first.score) * first.upvoteRatio * recencyBonus1
            let score2 = Double(second.score) * second.upvoteRatio * recencyBonus2
            
            return score1 > score2
        }
        
        // Update the MemesViewController
        memesVC.setInitialMemes(allMemes)
        navigationController?.pushViewController(memesVC, animated: true)
    }
} 