import RealmSwift
import RxSwift

class LinkParam: Object {
    @objc dynamic var key = ""
    @objc dynamic var value = ""
}

class Link: Object {
    @objc dynamic var path = ""
    @objc dynamic var dateAdded = Date()
    @objc dynamic var lastUsed = Date()
    @objc dynamic var lastBuiltPath = ""
    var lastParameters = List<LinkParam>()
    
    private let disposeBag = DisposeBag()
    
    static var all: Results<Link> {
        let descriptors: [SortDescriptor] = [SortDescriptor(keyPath: "lastUsed", ascending: false),
                                             SortDescriptor(keyPath: "dateAdded", ascending: false)]
        return try! Realm()
            .objects(self)
            .sorted(by: descriptors)
    }
    
    func didUse(withParams params: [String: String]?, fullPath: String) {
        let realm = try! Realm()
        try! realm.write { [weak self] in
            self?.lastUsed = Date()
            self?.lastBuiltPath = fullPath
            
            if let params = params {
                self?.lastParameters.removeAll()
                params.forEach { (key, value) in
                    let lp = LinkParam()
                    lp.key = key
                    lp.value = value
                    self?.lastParameters.append(lp)
                }
            }
        }
    }
    
    
    // weird but hey ho
    func populateParameters(presentingAlertFrom viewController: UIViewController, completed: @escaping (LinkInfo) -> Void) {
        let paramRegex = "\\$\\{(.*?)\\}" // e.g. /pickem/${tournamentId}
        let matches = try! NSRegularExpression(pattern: paramRegex)
            .matches(in: path, options: [], range: NSRange(path.startIndex..., in: path))
        
        Observable
            .from(matches)
            .concatMap { [weak self] match -> Observable<(RegexReplacement)> in
                guard
                    let path = self?.path,
                    let strongSelf = self,
                    let swiftRange = Range(match.range, in: path) else { return Observable.empty() }
                
                let viewModel = TextFieldAlertViewModel(title: "Enter value for \(String(path[swiftRange]))", message: nil)
                return strongSelf
                    .show(textFieldAlertViewModel: viewModel, from: viewController)
                    .map { textInput in RegexReplacement(checkingResult: match, replacement: textInput) }
            }
            .toArray()
            .subscribe(onNext: { [weak self] matchesToUserInput in
                guard let strongSelf = self else { return }
                let output = strongSelf.replaceChunks(forValues: matchesToUserInput)
                completed(output)
            })
            .disposed(by: disposeBag)
        
        
    }
    
    private func replaceChunks(forValues matchesToUserInput: [RegexReplacement]) -> LinkInfo {
        guard !matchesToUserInput.isEmpty else { return LinkInfo(fullPath: path, replacements: [:]) }
        
        var output = ""
        var previousMatch: NSTextCheckingResult?
        var replacements = [String: String]()
        for (i, regexReplacement) in matchesToUserInput.enumerated() {
            let (match, replacement) = (regexReplacement.checkingResult, regexReplacement.replacement)
            let currentMatchRange = Range(match.range, in: path)!
            
            if let previousMatch = previousMatch {
                let previousMatchRange = Range(previousMatch.range, in: path)!
                let chunk = path[previousMatchRange.upperBound..<currentMatchRange.lowerBound]
                output.append(String(chunk))
            } else {
                let chunk = path[path.startIndex..<currentMatchRange.lowerBound]
                output.append(String(chunk))
            }
            
            let currentKey = String(path[Range(match.range, in: path)!])
            replacements[currentKey] = replacement
            output.append(replacement)
            
            if i == matchesToUserInput.count - 1 {
                let chunk = path[currentMatchRange.upperBound...]
                output.append(String(chunk))
            }
            
            previousMatch = match
        }
        
        return LinkInfo(fullPath: output, replacements: replacements)
    }
    
    struct TextFieldAlertViewModel {
        let title: String?
        let message: String?
    }
    
    private func show(textFieldAlertViewModel: TextFieldAlertViewModel, from viewController: UIViewController) -> Observable<String> {
        return Observable.create { observer in
            let alert = UIAlertController(title: textFieldAlertViewModel.title,
                                          message: textFieldAlertViewModel.message,
                                          preferredStyle: .alert)
            
            alert.addAction(.init(title: "Cancel",
                                  style: .cancel,
                                  handler: { _ in
                                    observer.onCompleted() }))
            
            alert.addAction(.init(title: "Submit",
                                  style: .default,
                                  handler: { _ in
                                    observer.onNext(alert.textFields?.first?.text ?? "")
                                    observer.onCompleted() }))
            
            alert.addTextField(configurationHandler: { _ in })
            
            viewController.present(alert, animated: true, completion: nil)
            
            return Disposables.create {
                alert.dismiss(animated: true, completion: nil)
            }
        }
    }
    
}

struct LinkInfo {
    let fullPath: String
    let replacements: [String: String]
}

struct RegexReplacement {
    let checkingResult: NSTextCheckingResult
    let replacement: String
}
