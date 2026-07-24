@Entry
@Component
struct QuickCategoriesWidgetCard {
  private readonly abilityName: string = 'EntryAbility';

  build() {
    FormLink({
      action: 'router',
      abilityName: this.abilityName,
      params: { message: 'quick-categories' }
    }) {
      Column() {
        Row() {
          Column() {
            Text('快捷分类')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor('#16202C')
            Text('一键进入你的标签')
              .fontSize(11)
              .fontColor('#7B8795')
              .margin({ top: 4 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('✧')
            .fontSize(21)
            .fontColor('#607B9F')
            .width(34)
            .height(34)
            .textAlign(TextAlign.Center)
            .backgroundColor('#E9F0FF')
            .borderRadius(11)
        }
        .width('100%')
        Row({ space: 8 }) {
          Text('工作  1').fontSize(12).fontColor('#526B93').padding({ left: 11, right: 11, top: 9, bottom: 9 }).backgroundColor('#E9F0FF').borderRadius(12)
          Text('项目  1').fontSize(12).fontColor('#765AA7').padding({ left: 11, right: 11, top: 9, bottom: 9 }).backgroundColor('#F3E9FF').borderRadius(12)
        }
        .width('100%')
        .margin({ top: 18 })
        Row({ space: 8 }) {
          Text('生活  1').fontSize(12).fontColor('#4D826C').padding({ left: 11, right: 11, top: 9, bottom: 9 }).backgroundColor('#E5F7EF').borderRadius(12)
          Text('待整理  1').fontSize(12).fontColor('#A5763F').padding({ left: 11, right: 11, top: 9, bottom: 9 }).backgroundColor('#FFF0DD').borderRadius(12)
        }
        .width('100%')
        .margin({ top: 8 })
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
