@tool
class_name CopilotProviderFactory
extends RefCounted
# Creates a provider instance according to the kind in settings.json.

static func create(config: CopilotConfig, provider_name: String) -> CopilotProvider:
	var provider: CopilotProvider = null
	if config.get_provider_kind(provider_name) == "anthropic":
		provider = CopilotAnthropicProvider.new()
	else:
		provider = CopilotOpenAiProvider.new()
	provider.setup(config, provider_name)
	return provider
