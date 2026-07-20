final Map<String, dynamic> officeMasterData = <String, dynamic>{};

void setOfficeMasterData(Map<String, dynamic> office) {
  officeMasterData
    ..clear()
    ..addAll(Map<String, dynamic>.from(office));
}
