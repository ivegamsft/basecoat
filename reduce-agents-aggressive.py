#!/usr/bin/env python3
"""
Aggressive agent reduction to get all agents under 500 tokens.
Targets: Remove verbose sections, collapse examples, simplify structure.
"""

from pathlib import Path
import re

TOKEN_MULTIPLIER = 1.35
TARGET_TOKENS = 500

def word_count(text: str) -> int:
    return len([w for w in re.split(r"\s+", text.strip()) if w])

def get_tokens(text: str) -> int:
    return round(word_count(text) * TOKEN_MULTIPLIER)

def aggressive_reduce(content: str, agent_name: str) -> str:
    """Apply aggressive reductions to get under 500 tokens."""
    
    # Extract frontmatter
    fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n?(.*)$', content, re.DOTALL)
    if not fm_match:
        return content
    
    frontmatter = fm_match.group(1)
    body = fm_match.group(2)
    
    # 1. DRASTICALLY shorten descriptions (max 80 words)
    def shorten_desc(fm):
        desc_match = re.search(r'description:\s*"([^"]+)"', fm)
        if desc_match:
            desc = desc_match.group(1)
            words = desc.split()
            if len(words) > 80:
                # Try to preserve USE FOR and DO NOT USE FOR
                if 'USE FOR' in desc:
                    parts = desc.split('USE FOR')
                    shortened = parts[0].strip() + 'USE FOR' + parts[1][:100]
                    if 'DO NOT USE FOR' in shortened:
                        shorter = shortened.split('DO NOT USE FOR')[0].strip()
                        shorter += ' DO NOT USE FOR: ' + shortened.split('DO NOT USE FOR')[1][:80]
                        shortened = shorter
                else:
                    shortened = ' '.join(words[:80])
                fm = fm.replace(f'description: "{desc}"', f'description: "{shortened}"')
        return fm
    
    frontmatter = shorten_desc(frontmatter)
    
    # 2. Remove or minimize entire sections
    sections_to_remove = [
        'Standards & References',
        'Model\n\n\*\*Recommended',
        'Governance',
        'Required Skills',
        'Integration Points',
        'Core Concepts'
    ]
    
    for section in sections_to_remove:
        # Remove section and its content until next ## heading
        pattern = rf'##\s+{section}.*?(?=\n##\s+|\Z)'
        body = re.sub(pattern, '', body, flags=re.DOTALL | re.IGNORECASE)
    
    # 3. Replace all yaml/json code blocks with simple bullet points
    code_blocks = list(re.finditer(r'```(yaml|json|python|bash|shell)\n(.*?)\n```', body, re.DOTALL))
    for match in reversed(code_blocks):  # Reverse to maintain positions
        code_content = match.group(2)
        lines = code_content.strip().split('\n')
        
        # Extract key info from code
        bullets = []
        for line in lines[:10]:  # First 10 lines only
            line = line.strip()
            if ':' in line and line[0] not in ['#', '-']:
                key = line.split(':')[0].strip()
                value = line.split(':', 1)[1].strip()
                if value:
                    bullets.append(f"- {key}: {value[:50]}")
        
        if bullets:
            replacement = "\n".join(bullets[:5])
        else:
            replacement = "- (code example)"
        
        body = body[:match.start()] + replacement + body[match.end():]
    
    # 4. Collapse verbose paragraphs into single sentences or bullets
    def make_concise(text):
        # Replace long paragraphs (> 100 words) with first sentence + key bullets
        paragraphs = re.split(r'\n\n+', text)
        result = []
        
        for para in paragraphs:
            if para.startswith('#') or para.startswith('```'):
                result.append(para)
            else:
                sentences = re.split(r'(?<=[.!?])\s+', para)
                words_count = len(para.split())
                
                if words_count > 100 and len(sentences) > 1:
                    # Keep first 2 sentences max
                    result.append(sentences[0] + ' ' + (sentences[1] if len(sentences) > 1 else ''))
                else:
                    result.append(para)
        
        return '\n\n'.join(result)
    
    body = make_concise(body)
    
    # 5. Remove all code blocks that aren't essential (most are)
    # Keep only if section is "Workflow" or "Example"
    workflows_only = re.split(r'(##\s+\w+\s*\n)', body)
    result_parts = []
    current_section = ""
    
    for part in workflows_only:
        if part.startswith('##'):
            current_section = part.lower()
            result_parts.append(part)
        else:
            if any(x in current_section for x in ['workflow', 'process', 'example', 'output']):
                result_parts.append(part)
            else:
                # Remove code blocks from non-workflow sections
                part_no_code = re.sub(r'```[\s\S]*?```\n?', '', part)
                result_parts.append(part_no_code)
    
    body = ''.join(result_parts)
    
    # 6. Collapse "Inputs" section to single line/bullets
    body = re.sub(
        r'(##\s+Inputs\s*\n\n)([\s\S]*?)(?=\n##)',
        lambda m: m.group(1) + '\n'.join(
            [l for l in m.group(2).split('\n')[:8] if l.strip()]
        ) + '\n',
        body
    )
    
    # 7. Collapse "Workflow" section to max 10 steps
    body = re.sub(
        r'(##\s+Workflow\s*\n\n)([\s\S]*?)(?=\n##)',
        lambda m: m.group(1) + '\n'.join(
            [l for l in m.group(2).split('\n')[:12] if l.strip() and not l.startswith('```')]
        ) + '\n',
        body,
        flags=re.IGNORECASE
    )
    
    # 8. Final cleanup - remove excessive whitespace
    body = re.sub(r'\n\n\n+', '\n\n', body)
    
    # 9. Keep Output section but shorten descriptions
    body = re.sub(
        r'- (\*\*[^*]+\*\*)(.*?)$',
        lambda m: '- ' + m.group(1) + ' ' + m.group(2)[:60] + ('...' if len(m.group(2)) > 60 else ''),
        body,
        flags=re.MULTILINE
    )
    
    return f"---\n{frontmatter}\n---\n\n{body}"

def main():
    repo_root = Path("F:\\Git\\basecoat")
    agents_dir = repo_root / "agents"
    
    # Process all agents exceeding 500 tokens
    over_budget = []
    total_reduction = 0
    
    for agent_path in sorted(agents_dir.glob("*.agent.md")):
        content = agent_path.read_text(encoding="utf-8")
        original_tokens = get_tokens(content)
        
        if original_tokens <= 500:
            continue
        
        agent_name = agent_path.stem
        reduced = aggressive_reduce(content, agent_name)
        reduced_tokens = get_tokens(reduced)
        reduction = original_tokens - reduced_tokens
        total_reduction += reduction
        
        status = "✓ OK" if reduced_tokens <= 500 else "⚠ NEEDS WORK"
        print(f"{agent_name:40} {original_tokens:5d} → {reduced_tokens:5d} tokens ({status})")
        
        # Update the file
        agent_path.write_text(reduced, encoding="utf-8")
        
        if reduced_tokens > 500:
            over_budget.append((agent_name, reduced_tokens, 500 - reduced_tokens))
    
    print(f"\n{'='*70}")
    print(f"Total reduction: {total_reduction} tokens across all agents")
    print(f"Still over budget: {len(over_budget)} agents")
    
    if over_budget:
        print(f"\nAgents still exceeding 500 tokens:")
        for name, tokens, deficit in sorted(over_budget, key=lambda x: -x[1])[:10]:
            print(f"  {name:40} {tokens:5d} tokens (need -{abs(deficit)} more)")

if __name__ == "__main__":
    main()
