import Foundation

@main
struct MacCleanerApp {
    static func main() async {
        let command = CLIParser.parse(arguments: CommandLine.arguments)
        let useCase = DIContainer.makeCleanupUseCase()

        switch command {
        case let .scan(json, includeReview, limit):
            let items = await useCase.scan(includeReviewItems: includeReview, limit: limit)
            useCase.printScan(items: items, asJSON: json)
            exit(0)
        case let .clean(yes, includeReview, limit):
            let code = await useCase.clean(includeReviewItems: includeReview, assumeYes: yes, limit: limit)
            exit(code)
        case .rules:
            useCase.listRules()
            exit(0)
        case .initConfig:
            exit(useCase.initConfig())
        case .help:
            CLIParser.printHelp()
            exit(0)
        }
    }
}
