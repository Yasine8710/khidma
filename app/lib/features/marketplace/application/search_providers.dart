import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/marketplace_domain.dart';
import 'marketplace_providers.dart';

/// Results per page. The server caps a page at 50 and the offset at 5000.
const searchPageSize = 20;

/// One page of results for [query] (its `offset` selects the page). Pages are
/// separate providers so a failed page can be retried alone and the pages
/// already shown stay put.
final searchPageProvider = FutureProvider.autoDispose
    .family<List<ProfessionalSummary>, SearchQuery>(
      retry: (n, e) => null,
      (ref, query) => ref.watch(marketplaceRepositoryProvider).search(query),
    );

/// One professional by id for the profile screen.
final professionalProvider = FutureProvider.autoDispose
    .family<ProfessionalSummary?, String>(
      retry: (n, e) => null,
      (ref, id) => ref.watch(marketplaceRepositoryProvider).professional(id),
    );
