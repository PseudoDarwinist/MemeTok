import UIKit

class TopicCollectionViewCell: UICollectionViewCell {
    static let identifier = "TopicCell"
    
    private let titleLabel: UILabel = {
        let label = UILabel()
        label.numberOfLines = 2
        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .label
        return label
    }()
    
    private let categoryLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        return label
    }()
    
    private let trendingScoreLabel: UILabel = {
        let label = UILabel()
        label.font = .systemFont(ofSize: 12)
        label.textColor = .systemRed
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setupViews()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupViews() {
        contentView.backgroundColor = .systemBackground
        contentView.layer.cornerRadius = 8
        contentView.layer.borderWidth = 1
        contentView.layer.borderColor = UIColor.systemGray5.cgColor
        
        contentView.addSubview(titleLabel)
        contentView.addSubview(categoryLabel)
        contentView.addSubview(trendingScoreLabel)
        
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        categoryLabel.translatesAutoresizingMaskIntoConstraints = false
        trendingScoreLabel.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            titleLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            categoryLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 4),
            categoryLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            categoryLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8),
            
            trendingScoreLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
            trendingScoreLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 8),
            trendingScoreLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -8)
        ])
    }
    
    func configure(with topic: MemeTopic) {
        titleLabel.text = topic.title
        categoryLabel.text = topic.category.rawValue
        trendingScoreLabel.text = "Trending Score: \(Int(topic.trendingScore))"
    }
    
    override func prepareForReuse() {
        super.prepareForReuse()
        titleLabel.text = nil
        categoryLabel.text = nil
        trendingScoreLabel.text = nil
    }
} 