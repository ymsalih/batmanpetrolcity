/// Saha grubundaki bir mesajı kimin yazdığı.
enum ChatSpeaker { usta, worker, player, system }

/// Saha grubu sohbetindeki tek mesaj. Konuşanın adı ve unvanı mesaj anındaki
/// hâliyle saklanır (işçi sonradan terfi etse de eski mesaj değişmez).
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.speaker,
    required this.text,
    required this.timeMs,
    this.workerId,
    this.name,
    this.title,
  });

  final int id;
  final ChatSpeaker speaker;
  final String text;
  final int timeMs;
  final int? workerId;
  final String? name;
  final String? title;

  Map<String, dynamic> toJson() => {
    'i': id,
    's': speaker.name,
    't': text,
    'm': timeMs,
    if (workerId != null) 'w': workerId,
    if (name != null) 'n': name,
    if (title != null) 'r': title,
  };

  factory ChatMessage.fromJson(Map<String, dynamic> j) => ChatMessage(
    id: (j['i'] as num?)?.toInt() ?? 0,
    speaker: ChatSpeaker.values.firstWhere((e) => e.name == j['s'], orElse: () => ChatSpeaker.system),
    text: j['t'] as String? ?? '',
    timeMs: (j['m'] as num?)?.toInt() ?? 0,
    workerId: (j['w'] as num?)?.toInt(),
    name: j['n'] as String?,
    title: j['r'] as String?,
  );
}

/// Oyuncunun cevap vermesini bekleyen sahne seçeneği.
class PendingChoice {
  const PendingChoice({required this.sceneId, required this.options});
  final String sceneId;
  final List<String> options;

  Map<String, dynamic> toJson() => {'id': sceneId, 'o': options};

  factory PendingChoice.fromJson(Map<String, dynamic> j) =>
      PendingChoice(sceneId: j['id'] as String? ?? '', options: ((j['o'] as List?) ?? const []).cast<String>());
}
