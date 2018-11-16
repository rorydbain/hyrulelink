import RealmSwift
import RxSwift

class LinkParam: Object {
    @objc dynamic var key = ""
    @objc dynamic var value = ""
}

class History: Object {
    @objc dynamic var timestamp = Date()
    @objc dynamic var parameterisedPath = ""
    var parameters = List<LinkParam>()
}

class Link: Object {
    @objc dynamic var path = ""
    @objc dynamic var dateAdded = Date()
    @objc dynamic var lastUse = Date()
    let uses = List<History>()
    
    static var all: Results<Link> {
        let descriptors: [SortDescriptor] = [SortDescriptor(keyPath: "lastUse", ascending: false),
                                             SortDescriptor(keyPath: "dateAdded", ascending: false)]
        
        return try! Realm()
            .objects(self)
            .sorted(by: descriptors)
        
    }
    
    static func didUse(link: Link, withParams params: [String: String]?, fullPath: String) {
        let realm = try! Realm()
        try! realm.write {
            let use = History()
            use.parameterisedPath = fullPath
            link.lastUse = Date()
            if let params = params {
                params.forEach { (key, value) in
                    let lp = LinkParam()
                    lp.key = key
                    lp.value = value
                    use.parameters.append(lp)
                }
            }
            link.uses.append(use)
        }
    }
    
    static func didUseLast(link: Link, use: History) {
        let realm = try! Realm()
        try! realm.write {
            link.lastUse = Date()
            if let existing = link.uses.index(of: use) {
                link.uses.remove(at: existing)
                link.uses.append(use)
            }
        }
    }
    
    // weird but hey ho
    func populateParameters(presentingAlertFrom viewController: UIViewController?) -> Observable<LinkInfo> {
        let paramRegex = "\\$\\{(.*?)\\}" // e.g. /pickem/${tournamentId}
        let matches = try! NSRegularExpression(pattern: paramRegex)
            .matches(in: path, options: [], range: NSRange(path.startIndex..., in: path))
        
        return Observable
            .from(matches)
            .concatMap { [weak self] match -> Observable<(RegexReplacement)> in
                guard
                    let vc = viewController,
                    let path = self?.path,
                    let swiftRange = Range(match.range, in: path) else { return Observable.empty() }
                
                return vc
                    .show(textFieldAlertViewModel: .init(title: "Enter value for \(String(path[swiftRange]))", message: nil))
                    .map { textInput in RegexReplacement(checkingResult: match, replacement: textInput) }
            }
            .toArray()
            .map(replaceChunks)
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
    
}

struct LinkInfo {
    let fullPath: String
    let replacements: [String: String]
}

struct RegexReplacement {
    let checkingResult: NSTextCheckingResult
    let replacement: String
}
