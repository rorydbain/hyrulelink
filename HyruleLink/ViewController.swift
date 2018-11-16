import UIKit
import RealmSwift
import RxRealm
import RxSwift
import RxCocoa

class ViewController: UITableViewController, TableViewCellDelegate {
    
    private let didTapNewSubject = PublishSubject<Link>()
    private let didTapUseLastSubject = PublishSubject<Link>()
    
    var didTapNew: AnyObserver<Link> {
        get {
            return didTapNewSubject.asObserver()
        }
    }
    
    var didTapLast: AnyObserver<Link> {
        get {
            return didTapUseLastSubject.asObserver()
        }
    }
    
    private let cellReuseIdentifier = "cell"
    private let disposeBag = DisposeBag()
    private var links = Link.all
    
    private let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Hyrule Link"
        navigationItem.rightBarButtonItem = addButton
        tableView.register(TableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
        setupRxStreams()
    }
    
    private func setupRxStreams() {
        Observable
            .changeset(from: links)
            .subscribe(onNext: handleChangeset)
            .disposed(by: disposeBag)
        
        let addNewPath = addButton.rx.tap
            .flatMap({ [unowned self] _ in
                self.show(textFieldAlertViewModel: .init(title: "Add new path", message: nil))
            })
        
        weak var welf = self
        let outputs = UseCase.makeStreams(inputs:
            UseCase.Inputs(newPathName: addNewPath,
                           didTapUseLast: didTapUseLastSubject.asObservable(),
                           didTapUseNew: didTapNewSubject.asObservable()), viewController: welf,
                                          disposeBag: disposeBag)
        
        outputs.showError
            .subscribe(onNext: { [weak self] alert in
                let alert = UIAlertController(title: alert.title, message: alert.message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
                self?.present(alert, animated: true, completion: nil)
            })
            .disposed(by: disposeBag)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let anyCell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        guard let cell = anyCell as? TableViewCell else { return anyCell }
        let link = links[indexPath.row]
        cell.link = link
        cell.delegate = self
        return cell
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return Link.all.count
    }
    
    private func handleChangeset(links: AnyRealmCollection<Link>, changeset: RealmChangeset?) {
        guard let tableView = self.tableView, let changes = changeset else {
            self.tableView.reloadData()
            return
        }
        tableView.beginUpdates()
        // move to usecase
        tableView.deleteRows(at: changes.deleted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        tableView.insertRows(at: changes.inserted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        tableView.reloadRows(at: changes.updated.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        tableView.endUpdates()
    }
    
}


struct OkAlert {
    let title: String
    let message: String?
}
