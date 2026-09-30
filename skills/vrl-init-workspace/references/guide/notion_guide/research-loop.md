# Research loop

```mermaid
flowchart TD
    CORE["Research Core<br/>Question & Direction"]
    IDEA["Ideas<br/>Testable hypotheses"]
    EXP["Experiments<br/>comparable, reproducible runs, eval"]
    FIND["Findings<br/>verified conclusions"]
    KB[("Notion CLI<br/>Knowledge Memory")]
    LIB[("Literature Library<br/>shared, curated")]

    CORE -->|derive| IDEA
    IDEA -->|test| EXP
    EXP -->|verify| FIND
    FIND -->|accumulate| KB
    KB -.->|inform next ideas| IDEA
    KB -.->|find| CORE
    LIB -.->|inspire| IDEA

    classDef human fill:#ECE8FB,stroke:#7B6BC9,color:#221A4A
    classDef ai fill:#E3F4E1,stroke:#4E9A48,color:#15330F
    classDef kb fill:#DCEBFA,stroke:#4A86C5,color:#0F2A44
    classDef lib fill:#FFF4D6,stroke:#C9A227,color:#3D2F0A
    class CORE,IDEA,FIND human
    class EXP ai
    class KB kb
    class LIB lib
```

## Legend

| Mark | Meaning |
|---|---|
| Purple | Human-In-Loop: set the direction, approve ideas, confirm findings |
| Green | AI-autonomous: run and compare experiments |
| Blue | Knowledge Memory: the project's Notion knowledge base, used through the Notion CLI |
| Yellow | Literature Library: shared by all projects, curated, feeds new ideas |
| Solid arrows | The forward chain: derive, test, verify, accumulate |
| Dashed arrows | The loops back to Ideas and the Research Core, and literature feeding Ideas |
