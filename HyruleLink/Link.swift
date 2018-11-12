import RealmSwift
import RxSwift

class Link: Object {
    @objc dynamic var path = ""
    @objc dynamic var dateAdded = Date()
    var lastUsed = RealmOptional<Double>()
    var lastParameters = List<String>()
    
    private let disposeBag = DisposeBag()
    
    static var all: Results<Link> {
        let descriptors: [SortDescriptor] = [SortDescriptor(keyPath: "lastUsed", ascending: false),
                                             SortDescriptor(keyPath: "dateAdded", ascending: false)]
        return try! Realm()
            .objects(self)
            .sorted(by: descriptors)
    }
    
    func didUse(withParams params: [String]) {
        let realm = try! Realm()
        try! realm.write { [weak self] in
            self?.lastUsed.value = Date().timeIntervalSince1970
            
            self?.lastParameters.removeAll()
            params.forEach({ self?.lastParameters.append($0) })
        }
    }
    
    
    // weird but hey ho
    func populateParameters(presentingAlertFrom viewController: UIViewController, completed: @escaping (String) -> Void) {
        let paramRegex = "\\$\\{(.*?)\\}" // e.g. /pickem/${tournamentId}
        let matches = try! NSRegularExpression(pattern: paramRegex).matches(in: path, options: [], range: NSRange(path.startIndex..., in: path))
        
        var matchesToUserInput = [(NSTextCheckingResult, String)]()
        Observable.from(matches)
            .concatMap { [weak self] match -> Observable<(NSTextCheckingResult,String)> in
                guard let strongSelf = self else { return Observable.empty() }
                return strongSelf.getParam(forMatch: match, viewController: viewController)
            }.scan([(NSTextCheckingResult, String)](), accumulator: { (total, arg1) in
                let (match, userReplacement) = arg1
                var mutableArray = total
                mutableArray.append((match, userReplacement))
                return mutableArray
            }).subscribe(onNext: { dict in
                matchesToUserInput = dict
            }, onError: nil,
               onCompleted: { [weak self] in
                guard let strongSelf = self else { return }
                let output = strongSelf.replaceChunks(forValues: matchesToUserInput)
                completed(output)
            }).disposed(by: disposeBag)
        
        
    }
    
    private func replaceChunks(forValues matchesToUserInput: [(NSTextCheckingResult, String)]) -> String {
        guard !matchesToUserInput.isEmpty else { return path }
        
        var output = ""
        var previousMatch: NSTextCheckingResult?
        for (i, args) in matchesToUserInput.enumerated() {
            let (match, replacement) = args
            let currentMatchRange = Range(match.range, in: path)!
            
            if let previousMatch = previousMatch {
                let previousMatchRange = Range(previousMatch.range, in: path)!
                let chunk = path[previousMatchRange.upperBound..<currentMatchRange.lowerBound]
                output.append(String(chunk))
            } else {
                let chunk = path[path.startIndex..<currentMatchRange.lowerBound]
                output.append(String(chunk))
            }
            
            output.append(replacement)
            
            if i == matchesToUserInput.count - 1 {
                let chunk = path[currentMatchRange.upperBound...]
                output.append(String(chunk))
            }
            
            previousMatch = match
        }
        
        return output
    }
    
    private func getParam(forMatch match: NSTextCheckingResult, viewController: UIViewController) -> Observable<(NSTextCheckingResult,String)> {
        let arg = String(path[Range(match.range, in: path)!])
        return Observable.create({ observer in
            let alert = UIAlertController(title: "Enter value for \(arg)", message: nil, preferredStyle: .alert)
            let cancel = UIAlertAction(title: "Cancel", style: .cancel, handler: { _ in observer.onCompleted() })
            let next = UIAlertAction(title: "Next", style: .default, handler: { _ in
                let text = alert.textFields![0].text!
                observer.onNext((match, text))
                observer.onCompleted()
            })
            alert.addTextField { _ in }
            alert.addAction(cancel)
            alert.addAction(next)
            viewController.present(alert, animated: true, completion: nil)
            return Disposables.create {
                alert.dismiss(animated: true, completion: nil)
            }
        })
    }
    
}
