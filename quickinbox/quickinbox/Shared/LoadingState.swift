enum LoadingState<Value> {
    case idle
    case loading
    case loaded(Value)
    case failed(String)
}

extension LoadingState: Sendable where Value: Sendable {}
