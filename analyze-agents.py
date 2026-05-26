#!/usr/bin/env python3
"""Analyze agents exceeding 500 tokens and show top candidates for reduction."""

from pathlib import Path
import re

TOKEN_MULTIPLIER = 1.35

def word_count(text: str) -> int:
    return len([w for w in re.split(r"\s+", text.strip()) if w])

def analyze_agent(agent_path: Path):
    content = agent_path.read_text(encoding="utf-8")
    words = word_count(content)
    tokens = round(words * TOKEN_MULTIPLIER)
    
    # Extract frontmatter and body
    fm_match = re.match(r'^---\s*\n(.*?)\n---\s*\n?(.*)$', content, re.DOTALL)
    frontmatter = fm_match.group(1) if fm_match else ""
    body = fm_match.group(2) if fm_match else content
    
    fm_words = word_count(frontmatter)
    body_words = word_count(body)
    
    # Count sections
    section_count = len(re.findall(r'^##\s+', body, re.MULTILINE))
    
    # Count code blocks
    code_blocks = len(re.findall(r'```', body))
    
    # Count examples (heuristic: "example" in lowercase)
    example_count = len(re.findall(r'\bexample\b', body, re.IGNORECASE))
    
    return {
        'name': agent_path.name.replace('.agent.md', ''),
        'path': agent_path,
        'words': words,
        'tokens': tokens,
        'frontmatter_words': fm_words,
        'body_words': body_words,
        'sections': section_count,
        'code_blocks': code_blocks,
        'examples': example_count,
        'content': content
    }

def main():
    repo_root = Path("F:\\Git\\basecoat")
    agents_dir = repo_root / "agents"
    
    agents = []
    for agent_path in sorted(agents_dir.glob("*.agent.md")):
        agent = analyze_agent(agent_path)
        if agent['tokens'] > 500:
            agents.append(agent)
    
    print(f"Agents exceeding 500 tokens: {len(agents)}")
    print()
    print("Top 20 agents by token count:")
    print("-" * 80)
    
    for i, agent in enumerate(sorted(agents, key=lambda a: -a['tokens'])[:20], 1):
        print(f"{i:2d}. {agent['name']:<40} {agent['tokens']:4d} tokens ({agent['words']} words)")
        print(f"    Frontmatter: {agent['frontmatter_words']} words | Sections: {agent['sections']} | "
              f"Code blocks: {agent['code_blocks']} | Examples: {agent['examples']}")
        print()
    
    print("-" * 80)
    print(f"\nTotal agents exceeding 500 tokens: {len(agents)}")
    print(f"Total agents in repository: {len(list(agents_dir.glob('*.agent.md')))}")
    
    # Save detailed report
    report_path = repo_root / "agent-token-reduction-plan.txt"
    with open(report_path, 'w') as f:
        f.write(f"Agent Token Reduction Analysis\n")
        f.write(f"=" * 80 + "\n\n")
        f.write(f"Total agents exceeding 500 tokens: {len(agents)}\n\n")
        f.write(f"All agents exceeding 500 tokens (sorted by tokens DESC):\n")
        f.write("-" * 80 + "\n")
        for agent in sorted(agents, key=lambda a: -a['tokens']):
            f.write(f"{agent['name']:<40} {agent['tokens']:4d} tokens ({agent['words']} words)\n")
    
    print(f"\nDetailed report saved to: {report_path}")

if __name__ == "__main__":
    main()
