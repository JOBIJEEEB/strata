import 'package:file_picker/file_picker.dart' as fp;
import 'dart:mirrors';

void main() {
  var declaration = reflectClass(fp.FilePicker);
  print('Members of FilePicker:');
  declaration.staticMembers.forEach((k, v) => print(MirrorSystem.getName(k)));
}
