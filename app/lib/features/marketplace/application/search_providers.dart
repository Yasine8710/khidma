import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/marketplace_domain.dart';
import 'home_providers.dart';
import 'marketplace_providers.dart';

/// What the basic search screen asks for. Filters and sorting arrive in the
/// next slice; the record keeps equality so identical asks share a result.
typedef SearchRequest = ({String text, int? categoryId});

final searchResultsProvider = FutureProvider.autoDispose
    .family<List<ProfessionalSummary>, SearchRequest>(retry: (n, e) => null, (
      ref,
      request,
    ) {
      final place = ref.watch(selectedPlaceProvider);
      return ref
          .watch(marketplaceRepositoryProvider)
          .search(
            SearchQuery(
              text: request.text.trim().isEmpty ? null : request.text,
              categoryId: request.categoryId,
              governorateId: place?.governorateId,
              cityId: place?.cityId,
              limit: 30,
            ),
          );
    });

/// One professional by id for the profile screen.
final professionalProvider = FutureProvider.autoDispose
    .family<ProfessionalSummary?, String>(
      retry: (n, e) => null,
      (ref, id) => ref.watch(marketplaceRepositoryProvider).professional(id),
    );
