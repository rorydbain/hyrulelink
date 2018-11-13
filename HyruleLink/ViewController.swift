import UIKit
import RealmSwift
import RxRealm
import RxSwift
import RxCocoa

class ViewController: UITableViewController, TableViewCellDelegate {
    
    private let cellReuseIdentifier = "cell"
    private let disposeBag = DisposeBag()
    private var links = Link.all
    
    private let addButton = UIBarButtonItem(barButtonSystemItem: .add, target: nil, action: nil)
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Hyrule Link"
        
        Observable
            .changeset(from: links)
            .subscribe(onNext: handleChangeset)
            .disposed(by: disposeBag)
        
        setupAddButton()
        tableView.register(TableViewCell.self, forCellReuseIdentifier: cellReuseIdentifier)
    }
    
    private func setupAddButton() {
        navigationItem.rightBarButtonItem = addButton
        addButton.rx.tap
            .subscribe(onNext: { [weak self] _ in
                self?.showAddUI()
            })
            .disposed(by: disposeBag)
    }
    
    private func showAddUI() {
        let alert = UIAlertController(title: "Add new path", message: nil, preferredStyle: .alert)
        let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        let add = UIAlertAction(title: "Add", style: .default, handler: { [weak self] _ in self?.handleAddText(alert)})
        alert.addTextField { textField in
            textField.placeholder = "/survivor/${blob}"
        }
        alert.addAction(cancel)
        alert.addAction(add)
        present(alert, animated: true, completion: nil)
    }
    
    private func handleAddText(_ alert: UIAlertController) {
        guard let textField = alert.textFields?[0], let text = textField.text else { return }
        
        let link = Link()
        link.path = text
        
        Observable
            .just(link)
            .bind(to: Realm.rx.add(onError: { [weak self] elements, error in
                if let elements = elements {
                    self?.showError(title: "Failed to add", message: "Error \(error.localizedDescription) while saving objects \(String(describing: elements))")
                } else {
                    self?.showError(title: "Failed to add", message: "Error \(error.localizedDescription) while opening realm.")
                }
            })).disposed(by: disposeBag)
    }
    
    private func showError(title: String, message: String?) {
        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        present(alert, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let anyCell = tableView.dequeueReusableCell(withIdentifier: cellReuseIdentifier, for: indexPath)
        guard let cell = anyCell as? TableViewCell else { return anyCell }
        let link = links[indexPath.row]
        cell.link = link
        cell.delegate = self
        return cell
    }
    
    func didTapUseNew(link: Link) {
        link.populateParameters(presentingAlertFrom: self) { [weak self] linkInfo in
            self?.open(path: linkInfo.fullPath, completion: {
                link.didUse(withParams: linkInfo.replacements, fullPath: linkInfo.fullPath)
            })
        }
    }
    
    func didTapUseLast(link: Link) {
        self.open(path: link.lastBuiltPath) {
            link.didUse(withParams: nil, fullPath: link.lastBuiltPath)
        }
    }
    
    private func open(path: String, completion: @escaping () -> Void) {
        let urlString = "https://www.fanduel.com\(path)"
        if let url = URL(string: urlString) {
            UIApplication.shared.open(url, options: [:], completionHandler: { _ in
                completion()
            })
        } else {
            showError(title: "Failed to make url", message: "Could not make url with text '\(urlString)'")
        }
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
        tableView.deleteRows(at: changes.deleted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        tableView.insertRows(at: changes.inserted.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        tableView.reloadRows(at: changes.updated.map { IndexPath(row: $0, section: 0) }, with: .automatic)
        tableView.endUpdates()
    }
    
}

