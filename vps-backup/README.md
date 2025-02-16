# VPS备份工具

一个功能强大的VPS自动备份解决方案，支持WebDAV远程存储和灵活的定时备份策略。

## 特性

- 支持完整备份和增量备份
- WebDAV远程存储集成
- 灵活的定时备份配置
- 智能的备份文件管理
- 自动清理过期备份
- 保留最小备份数量
- 详细的日志记录

## 一键安装

```bash
sudo bash -c "$(curl -fsSL https://raw.githubusercontent.com/jump1999/potential-train/main/vps-backup/scripts/quick_install.sh)"
```

## 目录结构

```
vps-backup/
├── src/          # 源代码
│   └── backup.sh # 主程序
├── scripts/      # 安装和工具脚本
│   ├── install.sh
│   └── quick_install.sh
└── docs/         # 文档
    └── README.md # 详细使用说明
```

## 详细文档

查看 [详细使用说明](docs/README.md) 了解更多信息。

## 许可证

MIT License

## 作者

- [@jump1999](https://github.com/jump1999)
