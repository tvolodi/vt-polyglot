class Story {
  String author;
  String theme;
  String name;
  bool selected;

  Story({required this.author, required this.theme, required this.name, this.selected = false});
}