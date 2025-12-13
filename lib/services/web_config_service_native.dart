import '../repositories/spacetimedb_notes_repository.dart';
import '../blocs/config/config_cubit.dart';

class WebConfigService {
  static Future<void> tryAutoConfigureFromServer(SpacetimeDbNotesRepository repo) async {}
  static Future<void> tryAutoConfigureOpenCode(ConfigCubit configCubit) async {}
}
