part of shunting_dart;

/**
 * A stack of elements with a LIFO interface.
 */
class Stack<E> {

  Queue<E> queue = new Queue<E>();

  /**
   * Add an element to the top of this stack.
   */
  push(E element) {
    queue.addFirst(element);
  }

  /**
   * Get the element from the top of this stack.
   * The element is _not_ removed.
   * Throws EmptyStackException if this stack is empty.
   */
  E get top {
    if(isEmpty) {
      throw new EmptyStackException('Stack is empty.');
    }

    return queue.first;
  }

  /**
   * Returns and removes the top most element from this stack.
   * Throw EmptyStackException if this stack is empty.
   */
  E pop() {
    if(isEmpty) {
      throw new EmptyStackException('Stack is empty.');
    }

    return queue.removeFirst();
  }

  /**
   * Returns true if this stack is empty.
   */
  bool get isEmpty => queue.isEmpty;

  /**
   * Returns false if this stack is empty.
   */
  bool get isNotEmpty => !isEmpty;
}

/**
 * Exception thrown when trying to read from an empty stack.
 */
class EmptyStackException implements Exception {
  String msg;

  EmptyStackException(this.msg);
}