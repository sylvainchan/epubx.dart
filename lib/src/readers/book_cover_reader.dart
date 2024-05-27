import 'dart:async';

import 'package:collection/collection.dart' show IterableExtension;
import 'package:image/image.dart' as images;

import '../ref_entities/epub_book_ref.dart';
import '../ref_entities/epub_content_file_ref.dart';
import '../schema/opf/epub_manifest_item.dart';
import '../schema/opf/epub_metadata_meta.dart';

class BookCoverReader {
  static Future<images.Image?> readBookCover(EpubBookRef bookRef) async {
    var metaItems = bookRef.Schema!.Package!.Metadata!.MetaItems;
    if (metaItems == null || metaItems.isEmpty) return null;

    var coverMetaItem = metaItems.firstWhereOrNull(
        (EpubMetadataMeta metaItem) =>
            (metaItem.Name != null &&
                metaItem.Name!.toLowerCase().contains('cover')) ||
            (metaItem.Attributes?.values.firstWhereOrNull(
                    (element) => element.toLowerCase().contains("cover"))) !=
                null);

    if (coverMetaItem == null) {
      return null;
    }

    String? coverManifestId;
    String? coverImageFileName;
    if (coverMetaItem.Content != null && coverMetaItem.Content!.isNotEmpty) {
      coverManifestId = coverMetaItem.Content;
    } else {
      coverImageFileName = coverMetaItem.Attributes?["content"];
    }

    if (coverManifestId != null && coverManifestId.isNotEmpty) {
      // file name of the cover image or get file name
      var coverManifestItem = bookRef.Schema!.Package!.Manifest!.Items!
          .firstWhereOrNull((EpubManifestItem manifestItem) =>
              manifestItem.Id!.toLowerCase() == coverManifestId!.toLowerCase());

      if (coverManifestItem == null) {
        throw Exception(
            'Incorrect EPUB manifest: item with ID = \"${coverMetaItem.Content}\" is missing.');
      }

      final firstFoundFile = bookRef.Content!.AllFiles!.keys.firstWhereOrNull(
          (element) => element.contains(coverManifestItem.Href!));

      if (firstFoundFile == null) {
        throw Exception(
            'Incorrect EPUB manifest: item with href = \"${coverManifestItem.Href}\" is missing.');
      }

      coverImageFileName = firstFoundFile;
    } else if (coverImageFileName != null && coverImageFileName.isNotEmpty) {
      if (bookRef.Schema!.Package!.Manifest!.Items!.firstWhereOrNull(
              (element) => element.Id == coverImageFileName!) !=
          null) {
        coverImageFileName = bookRef.Schema!.Package!.Manifest!.Items!
            .firstWhereOrNull((element) => element.Id == coverImageFileName!)!
            .Href!;
      }
    } else {
      throw Exception("Incorrect EPUB metadata: cover image is not specified.");
    }

    final correctPath =
        bookRef.Content!.AllFiles!.keys.firstWhereOrNull((element) {
      return element.contains(coverImageFileName!) ||
          coverImageFileName!.contains(element.split('/').last);
    });

    if (correctPath == null) {
      throw Exception(
          'Incorrect EPUB manifest: item with href = \"$coverImageFileName\" is missing.');
    }

    EpubContentFileRef? coverImageContentFileRef;
    coverImageContentFileRef = bookRef.Content!.AllFiles![correctPath!];

    if (coverImageContentFileRef == null) {
      throw Exception(
          'Incorrect EPUB manifest: item with href = \"$coverImageFileName\" is missing.');
    }

    var coverImageContent =
        await coverImageContentFileRef!.readContentAsBytes();
    var retval = images.decodeImage(coverImageContent);
    return retval;
  }
}
