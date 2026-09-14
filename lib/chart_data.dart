import 'dart:collection';

/// A `Map<K,V>` that calls [_onChange] after every mutation.
class ObservableMap<K, V> extends MapBase<K, V> {
  ObservableMap(this._inner, this._onChange);
  final Map<K, V> _inner;
  final void Function() _onChange;

  @override
  V? operator [](Object? key) => _inner[key];

  @override
  void operator []=(K key, V value) {
    _inner[key] = value;
    _onChange();
  }

  @override
  Iterable<K> get keys => _inner.keys;

  @override
  V? remove(Object? key) {
    final result = _inner.remove(key);
    _onChange();
    return result;
  }

  @override
  void clear() {
    _inner.clear();
    _onChange();
  }
}
