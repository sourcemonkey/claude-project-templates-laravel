<?php

return [

    /*
    |--------------------------------------------------------------------------
    | エージェント別の出力先
    |--------------------------------------------------------------------------
    |
    | Boost の AI Guidelines を CLAUDE.md ではなく docs/ へ出力する。CLAUDE.md は
    | 本テンプレートの成果物（@docs/*.md の参照とフェーズ定義を持つ手書きファイル）で
    | あり、boost:install に再生成させてはならないため。生成された docs/boost-guidelines.md
    | は .gitignore で除外し、CLAUDE.md から @ 参照で読み込む。
    |
    | Boost のサービスプロバイダは mergeConfigFrom を使うため、ここに書かないキー
    | （enabled / browser_logs / rules / executable_paths 等）はパッケージ側の既定が
    | そのまま適用される。このファイルは agents の上書きだけを持てばよい。
    |
    */

    'agents' => [
        'claude_code' => [
            'guidelines_path' => 'docs/boost-guidelines.md',
            'skills_path' => '.claude/skills',
            'mcp_config_path' => '.mcp.json',
        ],
    ],

];
