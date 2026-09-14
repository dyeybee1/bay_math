enum LessonBlockType {
  heading,
  paragraph,
  image,
  keyIdea,
  workedExample,
  link;

  static LessonBlockType? fromSectionType(String? value) => switch (value) {
    'composer_heading' => LessonBlockType.heading,
    'composer_paragraph' => LessonBlockType.paragraph,
    'composer_image' => LessonBlockType.image,
    'composer_key_idea' => LessonBlockType.keyIdea,
    'composer_worked_example' => LessonBlockType.workedExample,
    'composer_link' => LessonBlockType.link,
    _ => null,
  };

  String get sectionType => switch (this) {
    LessonBlockType.heading => 'composer_heading',
    LessonBlockType.paragraph => 'composer_paragraph',
    LessonBlockType.image => 'composer_image',
    LessonBlockType.keyIdea => 'composer_key_idea',
    LessonBlockType.workedExample => 'composer_worked_example',
    LessonBlockType.link => 'composer_link',
  };

  String get label => switch (this) {
    LessonBlockType.heading => 'Heading',
    LessonBlockType.paragraph => 'Text',
    LessonBlockType.image => 'Image',
    LessonBlockType.keyIdea => 'Key idea',
    LessonBlockType.workedExample => 'Worked example',
    LessonBlockType.link => 'Link',
  };
}
