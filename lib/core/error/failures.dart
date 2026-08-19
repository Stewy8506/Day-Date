/// Failure types for the Day-Date engine.
library;

/// Base class for all failures.
sealed class Failure {
  final String message;
  const Failure(this.message);

  @override
  String toString() => '$runtimeType: $message';
}

/// Failure originating from local database operations.
class DatabaseFailure extends Failure {
  const DatabaseFailure(super.message);
}

/// Failure during initial seed data population.
class SeedFailure extends Failure {
  const SeedFailure(super.message);
}

/// Failure during schedule allocation (e.g., insufficient free time).
class AllocationFailure extends Failure {
  const AllocationFailure(super.message);
}
