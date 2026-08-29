import { WidgetFile } from '../../model/WidgetData';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct RecentFilesWidgetCard {
  private readonly abilityName: string = 'EntryAbility';
  @LocalStorageProp('totalCount') totalCount: number = 0;
  @LocalStorageProp('recentList') recentList: WidgetFile[] = [];

  build() {
    Column() {
      Row() {
        Column() {
          Text('最近文件')
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor('#16202C')
          Text(this.totalCount > 0 ? `收纳箱 · ${this.totalCount} 项` : '还没有整理文件')
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
      if (this.recentList.length === 0) {
        Text('暂无已整理文件')
          .fontSize(13)
          .fontColor('#A0AAB6')
          .alignSelf(ItemAlign.Start)
          .margin({ top: 22 })
      } else {
        ForEach(this.recentList, (file: WidgetFile) => {
          Row() {
            Text(file.icon)
              .fontSize(16)
              .fontColor('#607B9F')
              .width(30)
              .height(30)
              .textAlign(TextAlign.Center)
              .backgroundColor(file.color)
              .borderRadius(9)
            Text(file.name)
              .fontSize(13)
              .fontColor('#253243')
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .layoutWeight(1)
              .margin({ left: 8 })
          }
          .width('100%')
          .margin({ top: 12 })
        }, (file: WidgetFile) => file.name)
      }
    }
    .width('100%')
    .height('100%')
    .padding(18)
    .backgroundColor('#F9FBFFF0')
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({ width: 1, color: '#FFFFFFC9', radius: 24 })
    .shadow({ radius: 18, color: '#13243A20', offsetX: 0, offsetY: 7 })
    .borderRadius(24)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: this.abilityName,
        params: { message: 'recent-files' }
      });
    })
  }
}