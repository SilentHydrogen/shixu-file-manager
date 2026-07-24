@Entry
@Component
struct RecentFilesWidgetCard {
  private readonly abilityName: string = 'EntryAbility';

  build() {
    FormLink({
      action: 'router',
      abilityName: this.abilityName,
      params: { message: 'recent-files' }
    }) {
      Column() {
        Row() {
          Column() {
            Text('最近文件')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#16202C')
            Text('收纳箱 · 5 项')
              .fontSize(11)
              .fontColor('#7B8795')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('▦')
            .fontSize(21)
            .fontColor('#607B9F')
            .width(34)
            .height(34)
            .textAlign(TextAlign.Center)
            .backgroundColor('#E9F0FF')
            .borderRadius(11)
        }
        .width('100%')
        Row() {
          Text('▤')
            .fontSize(16)
            .fontColor('#607B9F')
            .width(30)
            .height(30)
            .textAlign(TextAlign.Center)
            .backgroundColor('#E9F0FF')
            .borderRadius(9)
          Text('鸿蒙应用设计规范.pdf')
            .fontSize(13)
            .fontColor('#253243')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 16 })
        Row() {
          Text('✦')
            .fontSize(16)
            .fontColor('#765AA7')
            .width(30)
            .height(30)
            .textAlign(TextAlign.Center)
            .backgroundColor('#F3E9FF')
            .borderRadius(9)
          Text('产品发布会视觉稿.fig')
            .fontSize(13)
            .fontColor('#253243')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
            .margin({ left: 8 })
        }
        .width('100%')
        .margin({ top: 9 })
      }
      .width('100%')
      .height('100%')
      .padding(18)
      .backgroundColor('#F9FBFFF0')
      .backgroundBlurStyle(BlurStyle.Thick)
      .border({ width: 1, color: '#FFFFFFC9', radius: 24 })
      .shadow({ radius: 18, color: '#13243A20', offsetX: 0, offsetY: 7 })
      .borderRadius(24)
    }
  }
}
