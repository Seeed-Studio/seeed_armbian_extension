"""Build a high/critical-only publication view of an official OCR JSON result."""
import argparse
import collections
import json
import pathlib

PUBLIC_COMMENT_FIELDS = {'path', 'content', 'existing_code', 'suggestion_code',
                         'start_line', 'end_line', 'category', 'severity'}


def publication_view(result):
    if result.get('status') not in {'complete', 'skipped'}:
        raise ValueError('Cannot publish an incomplete OCR result as an accepted review')
    comments = result.get('comments')
    if not isinstance(comments, list) or not all(isinstance(c, dict) for c in comments):
        raise ValueError('Expected an OCR comments array')
    counts = collections.Counter()
    kept = []
    for comment in comments:
        severity = str(comment.get('severity') or '').strip().lower()
        counts[severity if severity in {'critical', 'high', 'medium', 'low'} else 'unknown'] += 1
        if severity in {'high', 'critical'}:
            clean = {k: v for k, v in comment.items() if k in PUBLIC_COMMENT_FIELDS}
            clean['severity'] = severity
            kept.append(clean)
    head = result.get('manifest', {}).get('input', {}).get('resolved_head')
    if not isinstance(head, str) or len(head) != 40 or any(c not in '0123456789abcdef' for c in head):
        raise ValueError('Missing exact reviewed head')
    public = {'status': result['status'], 'comments': kept,
              'manifest': {'input': {'resolved_head': head}},
              'message': '本轮没有可发布的 high/critical 意见。其他严重度未发布；这不代表没有其他问题。'}
    audit = {'generated': len(comments), 'published_candidates': len(kept),
             'withheld': len(comments) - len(kept), 'by_severity': dict(counts)}
    return public, audit


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('source', type=pathlib.Path)
    parser.add_argument('publication', type=pathlib.Path)
    parser.add_argument('audit', type=pathlib.Path)
    args = parser.parse_args()
    public, audit = publication_view(json.loads(args.source.read_text()))
    args.publication.write_text(json.dumps(public, ensure_ascii=False) + '\n')
    args.audit.write_text(json.dumps(audit, ensure_ascii=False) + '\n')
    print(json.dumps(audit))


if __name__ == '__main__':
    main()
