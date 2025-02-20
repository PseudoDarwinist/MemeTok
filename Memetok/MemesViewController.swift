import UIKit

class MemesViewController: UIViewController {
    private let redditService = RedditService()
    private let storageService = StorageService()
    private let topicAnalysisService: TopicAnalysisService
    private var memes: [RedditPost] = []
    private var selectedTopic: MemeTopic?
    private var initialMemes: [RedditPost]?
    
    private lazy var collectionView: UICollectionView = {
        let layout = UICollectionViewFlowLayout()
        layout.scrollDirection = .vertical
        layout.minimumInteritemSpacing = 1
        layout.minimumLineSpacing = 1
        layout.sectionInset = UIEdgeInsets(top: 1, left: 1, bottom: 1, right: 1)
        
        let collectionView = UICollectionView(frame: .zero, collectionViewLayout: layout)
        collectionView.backgroundColor = .white
        collectionView.delegate = self
        collectionView.dataSource = self
        collectionView.alwaysBounceVertical = true
        collectionView.showsVerticalScrollIndicator = true
        collectionView.register(MemeCollectionViewCell.self, forCellWithReuseIdentifier: MemeCollectionViewCell.identifier)
        return collectionView
    }()
    
    init(topic: MemeTopic? = nil) {
        self.topicAnalysisService = TopicAnalysisService(storageService: storageService)
        self.selectedTopic = topic
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func setInitialMemes(_ memes: [RedditPost]) {
        self.initialMemes = memes
        if isViewLoaded {
            self.memes = memes
            collectionView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        
        if let initialMemes = initialMemes {
            self.memes = initialMemes
            collectionView.reloadData()
        } else {
            fetchMemes()
        }
    }
    
    private func setupUI() {
        title = selectedTopic?.title ?? "Trending Memes"
        view.backgroundColor = .systemBackground
        
        view.addSubview(collectionView)
        collectionView.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            collectionView.topAnchor.constraint(equalTo: view.topAnchor),
            collectionView.leftAnchor.constraint(equalTo: view.leftAnchor),
            collectionView.rightAnchor.constraint(equalTo: view.rightAnchor),
            collectionView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(self, action: #selector(refreshMemes), for: .valueChanged)
        collectionView.refreshControl = refreshControl
    }
    
    @objc private func refreshMemes() {
        if initialMemes != nil {
            // If we have initial memes, just end refreshing
            collectionView.refreshControl?.endRefreshing()
        } else {
            fetchMemes()
        }
    }
    
    private func fetchMemes() {
        Task {
            do {
                print("Starting to fetch memes...")
                if let topic = selectedTopic {
                    // Fetch memes for specific topic
                    self.memes = storageService.getMemesForTopic(topic.id)
                } else {
                    // Fetch all trending memes
                    let trendingMemes = try await redditService.analyzeTrending()
                    print("Got \(trendingMemes.count) subreddits of memes")
                    
                    self.memes = Array(trendingMemes.values.flatMap { $0 })
                    print("Total memes fetched: \(self.memes.count)")
                    
                    // Analyze and categorize memes
                    for meme in self.memes {
                        let topic = topicAnalysisService.analyzeMeme(meme)
                        self.storageService.saveMeme(meme, topicId: topic.id)
                    }
                }
                
                DispatchQueue.main.async {
                    self.collectionView.refreshControl?.endRefreshing()
                    self.collectionView.reloadData()
                    print("Collection view reloaded")
                }
            } catch {
                print("Error fetching memes: \(error)")
                DispatchQueue.main.async {
                    self.collectionView.refreshControl?.endRefreshing()
                    let alert = UIAlertController(title: "Error",
                                                message: "Failed to fetch memes: \(error.localizedDescription)",
                                                preferredStyle: .alert)
                    alert.addAction(UIAlertAction(title: "OK", style: .default))
                    self.present(alert, animated: true)
                }
            }
        }
    }
}

extension MemesViewController: UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        print("Number of memes in collection view: \(memes.count)")
        return memes.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        guard let cell = collectionView.dequeueReusableCell(withReuseIdentifier: MemeCollectionViewCell.identifier, for: indexPath) as? MemeCollectionViewCell else {
            return UICollectionViewCell()
        }
        
        cell.configure(with: memes[indexPath.item])
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let padding: CGFloat = 1
        let collectionViewSize = collectionView.frame.size.width - padding
        let width = collectionViewSize/2
        return CGSize(width: width - padding, height: width + 40)
    }
}

extension MemesViewController: UICollectionViewDelegate {
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        let meme = memes[indexPath.item]
        let detailVC = MemeDetailViewController(meme: meme)
        let navController = UINavigationController(rootViewController: detailVC)
        navController.modalPresentationStyle = .fullScreen
        present(navController, animated: true)
    }
}
