import '../models/parsed_sms_dto.dart';

abstract class SmsParserStrategy {
  /// Returns true if this strategy can handle the given sender.
  /// normalization of sender should be handled before calling this, or inside.
  /// But per requirements, engine normalizes sender.
  bool canParse(String sender);

  /// Parses the message body and returns a DTO.
  /// Returns null if parsing fails or keywords are missing.
  ParsedSmsDto? parse(String normalizedBody);
}
