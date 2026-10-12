# 릴리스 빌드(R8) 설정

# tflite_flutter가 넣는 tensorflow-lite-gpu는 GPU 옵션 클래스(tensorflow-lite-gpu-api)를
# 참조하지만 의존성에 없어서 R8이 실패합니다. 이 앱은 GPU 델리게이트를 쓰지 않으므로 무시합니다.
-dontwarn org.tensorflow.lite.gpu.**

# TFLite 런타임 클래스는 이름이 바뀌거나 지워지지 않도록 유지합니다.
-keep class org.tensorflow.lite.** { *; }
