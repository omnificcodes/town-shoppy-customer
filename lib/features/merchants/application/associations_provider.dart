import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/associations_repository.dart';
import '../data/models/association_ref.dart';

/// The active merchant associations, for Home's partner strip. Like
/// `merchantCategoriesProvider`, this does not watch `sessionEpochProvider`:
/// the list is public reference data, identical for every caller.
final associationsProvider = FutureProvider<List<AssociationRef>>((ref) {
  return ref.watch(associationsRepositoryProvider).listActive();
});
