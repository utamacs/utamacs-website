import 'package:utamacs_portal/features/documents/data/document_repository.dart'
    show SocietyDocument;
import 'package:utamacs_portal/shared/models/profile.dart';

abstract interface class IDocumentRepository {
  Future<List<SocietyDocument>> fetchDocuments();

  Future<void> archiveDocument(String documentId, Profile profile);

  Future<void> logDocumentAccess(String documentId);
}
