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
            .fontSize($r('app.float.font_size_body_lg'))
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.widget_text_primary'))
          Text(this.totalCount > 0 ? `收纳箱 · ${this.totalCount} 项` : '还没有整理文件')
            .fontSize($r('app.float.font_size_micro'))
            .fontColor($r('app.color.widget_text_body'))
            .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        Blank()
        Text('▦')
          .fontSize($r('app.float.font_size_md'))
          .fontColor($r('app.color.widget_accent_blue'))
          .width(34)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.widget_tint_blue'))
          .borderRadius($r('app.float.radius_sm'))
      }
      .width('100%')
      if (this.recentList.length === 0) {
        Text('暂无已整理文件')
          .fontSize($r('app.float.font_size_caption'))
          .fontColor($r('app.color.widget_text_caption'))
          .alignSelf(ItemAlign.Start)
          .margin({ top: 22 })
      } else {
        ForEach(this.recentList, (file: WidgetFile) => {
          Row() {
            Text(file.icon)
              .fontSize($r('app.float.font_size_body'))
              .fontColor($r('app.color.widget_accent_blue'))
              .width(30)
              .height(30)
              .textAlign(TextAlign.Center)
              .backgroundColor(file.color)
              .borderRadius($r('app.float.radius_sm'))
            Text(file.name)
              .fontSize($r('app.float.font_size_caption'))
              .fontColor($r('app.color.widget_text_dark'))
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
    .backgroundColor($r('app.color.widget_bg'))
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({ width: 1, color: $r('app.color.border_glass'), radius: 24 })
    .shadow({ radius: 18, color: $r('app.color.shadow_widget'), offsetX: 0, offsetY: 7 })
    .borderRadius($r('app.float.radius_xl'))
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: this.abilityName,
        params: { message: 'recent-files' }
      });
    })
  }
}
