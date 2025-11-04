class AIModelConfig {
  String function;
  String modelCode;
  String apiKey;

  AIModelConfig({
    required this.function,
    required this.modelCode,
    required this.apiKey,
  });

  Map<String, dynamic> toJson() => {
    'function': function,
    'modelCode': modelCode,
    'apiKey': apiKey,
  };

  factory AIModelConfig.fromJson(Map<String, dynamic> json) => AIModelConfig(
    function: json['function'],
    modelCode: json['modelCode'],
    apiKey: json['apiKey'],
  );
}