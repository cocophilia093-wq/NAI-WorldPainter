import 'package:get_it/get_it.dart';
import 'package:sqflite/sqflite.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nai_huishi/data/datasources/local/database_helper.dart';
import 'package:nai_huishi/data/datasources/local/llm_chat_local_datasource.dart';
import 'package:nai_huishi/data/datasources/local/settings_local_datasource.dart';
import 'package:nai_huishi/data/datasources/remote/llm_api_service.dart';
import 'package:nai_huishi/data/datasources/remote/novelai_api_service.dart';
import 'package:nai_huishi/data/datasources/remote/gpt_api_service.dart';
import 'package:nai_huishi/data/datasources/remote/nano_banana_api_service.dart';
import 'package:nai_huishi/data/datasources/remote/bing_search_service.dart';
import 'package:nai_huishi/data/datasources/remote/danbooru_api_service.dart';
import 'package:nai_huishi/data/repositories/artist_prompt_repository_impl.dart';
import 'package:nai_huishi/data/repositories/generation_repository_impl.dart';
import 'package:nai_huishi/data/repositories/history_repository_impl.dart';
import 'package:nai_huishi/data/repositories/llm_chat_repository_impl.dart';
import 'package:nai_huishi/data/repositories/preset_repository_impl.dart';
import 'package:nai_huishi/data/repositories/prompt_memory_repository_impl.dart';
import 'package:nai_huishi/data/repositories/prompt_template_repository_impl.dart';
import 'package:nai_huishi/data/repositories/settings_repository_impl.dart';
import 'package:nai_huishi/data/repositories/style_preset_repository_impl.dart';
import 'package:nai_huishi/domain/repositories/artist_prompt_repository.dart';
import 'package:nai_huishi/domain/repositories/generation_repository.dart';
import 'package:nai_huishi/domain/repositories/history_repository.dart';
import 'package:nai_huishi/domain/repositories/llm_chat_repository.dart';
import 'package:nai_huishi/domain/repositories/preset_repository.dart';
import 'package:nai_huishi/domain/repositories/prompt_memory_repository.dart';
import 'package:nai_huishi/domain/repositories/prompt_template_repository.dart';
import 'package:nai_huishi/domain/repositories/settings_repository.dart';
import 'package:nai_huishi/domain/repositories/style_preset_repository.dart';
import 'package:nai_huishi/domain/usecases/manage_artist_prompts.dart';
import 'package:nai_huishi/domain/usecases/generate_image.dart';
import 'package:nai_huishi/domain/usecases/get_history.dart';
import 'package:nai_huishi/domain/usecases/manage_llm_chat.dart';
import 'package:nai_huishi/domain/usecases/manage_presets.dart';
import 'package:nai_huishi/domain/usecases/manage_prompt_memories.dart';
import 'package:nai_huishi/domain/usecases/manage_prompt_templates.dart';
import 'package:nai_huishi/domain/usecases/manage_settings.dart';
import 'package:nai_huishi/domain/usecases/manage_style_presets.dart';
import 'package:nai_huishi/domain/usecases/save_image.dart';
import 'package:nai_huishi/domain/usecases/calibrate_with_danbooru.dart';
import 'package:nai_huishi/domain/usecases/extract_keywords.dart';
import 'package:nai_huishi/domain/usecases/search_danbooru_tags.dart';
import 'package:nai_huishi/domain/usecases/upscale_image.dart';
import 'package:nai_huishi/domain/repositories/super_resolution_repository.dart';
import 'package:nai_huishi/data/datasources/super_resolution_channel.dart';
import 'package:nai_huishi/data/repositories/super_resolution_repository_impl.dart';
import 'package:nai_huishi/core/queue/generation_queue.dart';
import 'package:nai_huishi/core/network/robust_http_adapter.dart';
import 'package:nai_huishi/presentation/viewmodels/artist_prompt_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/generation_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/history_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/llm_chat_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/preset_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/prompt_memory_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/prompt_template_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/settings_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/style_preset_viewmodel.dart';
import 'package:nai_huishi/presentation/viewmodels/super_resolution_viewmodel.dart';

final sl = GetIt.instance;

Future<void> configureDependencies() async {
  final prefs = await SharedPreferences.getInstance();
  sl.registerSingleton<SharedPreferences>(prefs);

  final db = await DatabaseHelper.instance.database;
  sl.registerSingleton<Database>(db);

  sl.registerSingleton<Dio>(createRobustDio());

  sl.registerSingleton<SettingsLocalDatasource>(SettingsLocalDatasource(sl<SharedPreferences>()));
  sl.registerSingleton<NovelAiApiService>(NovelAiApiService(sl<Dio>()));
  sl.registerSingleton<GptApiService>(GptApiService(sl<Dio>()));
  sl.registerSingleton<NanoBananaApiService>(NanoBananaApiService(sl<Dio>()));
  sl.registerSingleton<LlmApiService>(LlmApiService(sl<Dio>()));
  sl.registerSingleton<BingSearchService>(BingSearchService());
  sl.registerSingleton<DanbooruApiService>(DanbooruApiService());
  sl.registerSingleton<LlmChatLocalDatasource>(LlmChatLocalDatasource(sl<Database>()));

  final settingsRepo = SettingsRepositoryImpl(sl<SettingsLocalDatasource>());
  settingsRepo.setApiService(sl<NovelAiApiService>());
  sl.registerSingleton<SettingsRepository>(settingsRepo);

  sl.registerSingleton<GenerationRepository>(GenerationRepositoryImpl(
    apiService: sl<NovelAiApiService>(),
    gptApiService: sl<GptApiService>(),
    nanoApiService: sl<NanoBananaApiService>(),
    settingsRepo: sl<SettingsRepository>(),
  ));
  sl.registerSingleton<HistoryRepository>(HistoryRepositoryImpl(sl<Database>()));
  sl.registerSingleton<PresetRepository>(PresetRepositoryImpl(sl<Database>()));
  sl.registerSingleton<PromptMemoryRepository>(PromptMemoryRepositoryImpl(sl<Database>()));
  sl.registerSingleton<PromptTemplateRepository>(PromptTemplateRepositoryImpl(sl<Database>()));
  sl.registerSingleton<StylePresetRepository>(StylePresetRepositoryImpl(sl<Database>()));
  sl.registerSingleton<ArtistPromptRepository>(ArtistPromptRepositoryImpl(sl<Database>()));
  sl.registerSingleton<LlmChatRepository>(LlmChatRepositoryImpl(
    local: sl<LlmChatLocalDatasource>(),
    api: sl<LlmApiService>(),
  ));

  sl.registerSingleton<GenerationQueue>(GenerationQueue(
    sl<GenerationRepository>(),
    sl<HistoryRepository>(),
  ));

  sl.registerSingleton<GenerateImageUseCase>(GenerateImageUseCase(
    sl<HistoryRepository>(),
  ));
  sl.registerSingleton<GetHistoryUseCase>(GetHistoryUseCase(sl<HistoryRepository>()));
  sl.registerSingleton<ManagePresetsUseCase>(ManagePresetsUseCase(sl<PresetRepository>()));
  sl.registerSingleton<ManagePromptMemoriesUseCase>(ManagePromptMemoriesUseCase(sl<PromptMemoryRepository>()));
  sl.registerSingleton<ManagePromptTemplatesUseCase>(ManagePromptTemplatesUseCase(sl<PromptTemplateRepository>()));
  sl.registerSingleton<ManageSettingsUseCase>(ManageSettingsUseCase(sl<SettingsRepository>()));
  sl.registerSingleton<ManageStylePresetsUseCase>(ManageStylePresetsUseCase(sl<StylePresetRepository>()));
  sl.registerSingleton<ManageArtistPromptsUseCase>(ManageArtistPromptsUseCase(sl<ArtistPromptRepository>()));
  sl.registerSingleton<ManageLlmChatUseCase>(ManageLlmChatUseCase(sl<LlmChatRepository>()));
  sl.registerSingleton<SaveImageUseCase>(SaveImageUseCase(sl<HistoryRepository>()));
  sl.registerSingleton<CalibrateWithDanbooruUseCase>(
      CalibrateWithDanbooruUseCase(sl<DanbooruApiService>()));
  sl.registerSingleton<ExtractKeywordsUseCase>(
      ExtractKeywordsUseCase(sl<LlmApiService>()));
  sl.registerSingleton<SearchDanbooruTagsUseCase>(
      SearchDanbooruTagsUseCase(sl<DanbooruApiService>()));

  // 图片超分
  sl.registerSingleton<SuperResolutionChannel>(SuperResolutionChannel());
  sl.registerSingleton<SuperResolutionRepository>(
      SuperResolutionRepositoryImpl(sl<SuperResolutionChannel>()));
  sl.registerSingleton<UpscaleImageUseCase>(
      UpscaleImageUseCase(sl<SuperResolutionRepository>()));

  sl.registerFactory<GenerationViewModel>(() => GenerationViewModel(
    generateImage: sl<GenerateImageUseCase>(),
    manageSettings: sl<ManageSettingsUseCase>(),
    saveImage: sl<SaveImageUseCase>(),
    queue: sl<GenerationQueue>(),
  ));
  sl.registerFactory<SuperResolutionViewModel>(() => SuperResolutionViewModel(
    sl<UpscaleImageUseCase>(),
    sl<SaveImageUseCase>(),
  ));
  sl.registerLazySingleton<HistoryViewModel>(() => HistoryViewModel(sl<GetHistoryUseCase>(), sl<GenerationQueue>()));
  sl.registerFactory<PresetViewModel>(() => PresetViewModel(sl<ManagePresetsUseCase>()));
  sl.registerFactory<PromptMemoryViewModel>(() => PromptMemoryViewModel(sl<ManagePromptMemoriesUseCase>()));
  sl.registerFactory<PromptTemplateViewModel>(() => PromptTemplateViewModel(sl<ManagePromptTemplatesUseCase>()));
  sl.registerLazySingleton<SettingsViewModel>(() => SettingsViewModel(sl<ManageSettingsUseCase>()));
  sl.registerFactory<StylePresetViewModel>(() => StylePresetViewModel(sl<ManageStylePresetsUseCase>()));
  sl.registerFactory<ArtistPromptViewModel>(() => ArtistPromptViewModel(sl<ManageArtistPromptsUseCase>()));
  sl.registerFactory<LlmChatViewModel>(() => LlmChatViewModel(
    manageChat: sl<ManageLlmChatUseCase>(),
    manageSettings: sl<ManageSettingsUseCase>(),
    extract: sl<ExtractKeywordsUseCase>(),
    searchTags: sl<SearchDanbooruTagsUseCase>(),
    memories: sl<ManagePromptMemoriesUseCase>(),
  ));
}
