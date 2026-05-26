#!/usr/bin/env python3
"""
Reduce agents exceeding 500 tokens through systematic compression:
1. Shorten verbose descriptions
2. Replace verbose YAML examples with bullet points
3. Consolidate redundant sections
4. Remove unnecessary metadata
5. Simplify explanations
"""

from pathlib import Path
import re

TOKEN_MULTIPLIER = 1.35
TARGET_TOKENS = 500
TARGET_WORDS = int(TARGET_TOKENS / TOKEN_MULTIPLIER)  # ~370 words

def word_count(text: str) -> int:
    return len([w for w in re.split(r"\s+", text.strip()) if w])

def get_tokens(text: str) -> int:
    return round(word_count(text) * TOKEN_MULTIPLIER)

def reduce_agent(content: str) -> str:
    """Apply reduction techniques to agent content."""
    
    # Extract frontmatter and body
    fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n?(.*)$', content, re.DOTALL)
    if not fm_match:
        return content
    
    frontmatter = fm_match.group(1)
    body = fm_match.group(2)
    
    # 1. Shorten verbose frontmatter descriptions (limit to 120 words max)
    def shorten_description(fm):
        desc_match = re.search(r'description:\s*"([^"]+)"', fm)
        if desc_match:
            original_desc = desc_match.group(1)
            words = original_desc.split()
            if len(words) > 120:
                shortened = ' '.join(words[:120]).strip()
                # Keep USE FOR and DO NOT USE FOR sections if they exist
                if 'USE FOR:' in original_desc:
                    use_idx = original_desc.index('USE FOR:')
                    shortened = original_desc[:use_idx].strip()
                    shortened += ' USE FOR: ' + original_desc[use_idx + 8:].split('DO NOT USE FOR')[0].strip()
                    if 'DO NOT USE FOR' in original_desc:
                        do_not_idx = original_desc.index('DO NOT USE FOR:')
                        do_not_text = original_desc[do_not_idx + 15:].strip()
                        shortened += ' DO NOT USE FOR: ' + do_not_text
                fm = fm.replace(f'description: "{original_desc}"', f'description: "{shortened}"')
        return fm
    
    frontmatter = shorten_description(frontmatter)
    
    # 2. Remove overly verbose YAML code blocks - replace with bullet lists
    def compress_yaml_blocks(text):
        # Find YAML code blocks with lots of structure
        yaml_blocks = re.findall(r'```yaml\n(.*?)\n```', text, re.DOTALL)
        for block in yaml_blocks:
            lines = block.strip().split('\n')
            # If block is > 20 lines, try to compress it
            if len(lines) > 20:
                # Convert to bullet points for key-value pairs
                summary = []
                for line in lines:
                    if ':' in line and not line.strip().startswith('-'):
                        key = line.split(':')[0].strip()
                        value = line.split(':', 1)[1].strip() if ':' in line else ''
                        if key and value and len(key) < 30:
                            summary.append(f"- {key}: {value}")
                
                if summary and len(summary) > 3:
                    # Replace verbose YAML with summary
                    old_block = f"```yaml\n{block}\n```"
                    new_block = "\n".join(summary[:15])  # Keep top 15 bullet points
                    text = text.replace(old_block, new_block, 1)
        
        return text
    
    body = compress_yaml_blocks(body)
    
    # 3. Collapse verbose section descriptions into shorter forms
    def shorten_section_content(text):
        # Find overly long paragraphs (> 150 words) and condense
        paragraphs = re.split(r'\n\n+', text)
        shortened_paragraphs = []
        
        for para in paragraphs:
            if para.startswith('#'):  # Skip headings
                shortened_paragraphs.append(para)
            elif para.startswith('```'):  # Skip code blocks
                shortened_paragraphs.append(para)
            else:
                words = para.split()
                if len(words) > 150:
                    # Keep only first 120 words for verbose paragraphs
                    shortened = ' '.join(words[:120])
                    # Add ellipsis if we cut content
                    if len(words) > 120:
                        shortened += '...' if not shortened.endswith('.') else '.'
                    shortened_paragraphs.append(shortened)
                else:
                    shortened_paragraphs.append(para)
        
        return '\n\n'.join(shortened_paragraphs)
    
    body = shorten_section_content(body)
    
    # 4. Remove duplicate "Recommended" sections at end
    body = re.sub(r'\n## Model\s*\n\n?\*\*Recommended:\*\*.*?\n\n?', '', body, flags=re.DOTALL)
    
    # 5. Remove verbose "Governance" sections or make them very brief
    body = re.sub(
        r'\n## Governance\s*\n\nThis agent operates under.*?See `instructions/governance.*?`',
        '',
        body,
        flags=re.DOTALL
    )
    
    # 6. Compress long bullet lists - group related items
    def compress_lists(text):
        lines = text.split('\n')
        compressed = []
        bullet_group = []
        
        for line in lines:
            if line.startswith('- ') or line.startswith('  - '):
                bullet_group.append(line)
            else:
                # End of bullet group
                if len(bullet_group) > 15:
                    # Keep first 10, remove middle ones, keep last 2
                    compressed.extend(bullet_group[:10])
                    compressed.append('- ... (see full documentation)')
                    compressed.extend(bullet_group[-2:])
                else:
                    compressed.extend(bullet_group)
                compressed.append(line)
                bullet_group = []
        
        if bullet_group:
            if len(bullet_group) > 15:
                compressed.extend(bullet_group[:10])
                compressed.append('- ... (see full documentation)')
                compressed.extend(bullet_group[-2:])
            else:
                compressed.extend(bullet_group)
        
        return '\n'.join(compressed)
    
    body = compress_lists(body)
    
    # 7. Remove or shorten "Required Skills" and "Integration Points" if too long
    def shorten_references(text):
        # Shorten Required Skills section
        text = re.sub(
            r'(## Required Skills\s*\n\n)([^#]*?)(?=\n## |\Z)',
            lambda m: m.group(1) + '\n'.join(m.group(2).split('\n')[:5]) + '\n',
            text,
            flags=re.DOTALL
        )
        # Shorten Integration Points section
        text = re.sub(
            r'(## Integration Points\s*\n\n)([^#]*?)(?=\n## |\Z)',
            lambda m: m.group(1) + '\n'.join(m.group(2).split('\n')[:5]) + '\n',
            text,
            flags=re.DOTALL
        )
        return text
    
    body = shorten_references(body)
    
    # 8. Remove Standards & References section (often long)
    body = re.sub(r'\n## Standards & References.*?(\n## |\Z)', r'\1', body, flags=re.DOTALL)
    
    # Reconstruct
    result = f"---\n{frontmatter}\n---\n\n{body}"
    
    return result

def main():
    repo_root = Path("F:\\Git\\basecoat")
    agents_dir = repo_root / "agents"
    
    # Load list of agents to reduce (top ones exceeding 500 tokens significantly)
    agents_to_reduce = [
        "container-security",
        "agentops",
        "containerization-planner",
        "release-manager",
        "project-onboarding",
        "api-security",
        "secrets-manager",
        "policy-as-code-compliance",
        "orchestrator",
        "mcp-developer",
        "performance-analyst",
        "sre-engineer",
        "ux-designer",
        "penetration-test",
        "finops-advisor",
        "mlops",
        "dataops",
        "agent-designer",
        "api-designer",
        "prompt-coach",
    ]
    
    for agent_name in agents_to_reduce:
        agent_path = agents_dir / f"{agent_name}.agent.md"
        if not agent_path.exists():
            print(f"Skipping {agent_name}: file not found")
            continue
        
        content = agent_path.read_text(encoding="utf-8")
        original_tokens = get_tokens(content)
        
        # Apply reductions
        reduced = reduce_agent(content)
        reduced_tokens = get_tokens(reduced)
        
        print(f"{agent_name}: {original_tokens} → {reduced_tokens} tokens "
              f"({original_tokens - reduced_tokens} reduction)")
        
        if reduced_tokens > 500:
            print(f"  ⚠ Still over budget, needs manual review")
        
        # Write back if significant reduction achieved
        if reduced_tokens < original_tokens - 50:
            agent_path.write_text(reduced, encoding="utf-8")
            print(f"  ✓ Updated")
        
        print()

if __name__ == "__main__":
    main()
