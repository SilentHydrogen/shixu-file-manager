import { WidgetFile } from '../../model/WidgetData';
import { widgetThemeColor } from '../../model/WidgetTheme';
import { Icon } from '../../components/Icon';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct RecentFilesWidgetCard {
  private readonly abilityName: string = 'EntryAbility';
  @LocalStorageProp('skinTheme') skinTheme: string = 'teal';
  @LocalStorageProp('totalCount') totalCount: number = 0;
  @LocalStorageProp('recentList') recentList: WidgetFile[] = [];

  private color(name: string): string {
    return widgetThemeColor(this.skinTheme, name);
  }

  build() {
    Column() {
      Row() {
        Text('最近收纳')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.color('header_text'))
        Blank()
        Icon({ source: $r('app.media.icon_plus'), iconSize: 22, tint: this.color('header_text') })
          .width(30)
          .height(30)
          .onClick(() => {
            postCardAction(this, {
              action: 'router',
              abilityName: this.abilityName,
              params: { message: 'quick-add' }
            });
          })
      }
      .width('100%')
      .padding({ left: 16, right: 12, top: 13, bottom: 12 })
      .backgroundColor(this.color('header_bg'))

      Column() {
        if (this.recentList.length === 0) {
          Text(this.totalCount > 0 ? `已收纳 ${this.totalCount} 项` : '暂无已整理文件')
            .fontSize(13)
            .fontColor(this.color('text_caption'))
            .alignSelf(ItemAlign.Start)
            .margin({ top: 17, bottom: 17 })
        } else {
          ForEach(this.recentList.slice(0, 3), (file: WidgetFile, index: number) => {
            Row() {
              Row()
                .width(4)
                .height(24)
                .backgroundColor(this.color('row_accent'))
                .borderRadius(2)
              Column() {
                Text(file.name)
                  .fontSize(14)
                  .fontColor(this.color('text_primary'))
                  .maxLines(1)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                Text(file.tag.length > 0 ? file.tag : '未分类')
                  .fontSize(11)
                  .fontColor(this.color('text_caption'))
                  .margin({ top: 3 })
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              .margin({ left: 10 })
            }
            .width('100%')
            .padding({ top: 11, bottom: 11 })
            .border({ width: { bottom: index < this.recentList.slice(0, 3).length - 1 ? 1 : 0 }, color: this.color('divider') })
          }, (file: WidgetFile) => `${file.name}-${file.tag}`)
          if (this.totalCount > this.recentList.length) {
            Text(`共 ${this.totalCount} 项`)
              .fontSize(11)
              .fontColor(this.color('text_caption'))
              .alignSelf(ItemAlign.End)
              .margin({ top: 8, bottom: 8 })
          }
        }
      }
      .width('100%')
      .padding({ left: 16, right: 16 })
      .backgroundColor(this.color('widget_bg'))
    }
    .width('100%')
    .height('100%')
    .backgroundColor(this.color('widget_bg'))
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({ width: 1, color: $r('app.color.border_glass'), radius: 24 })
    .shadow({ radius: 18, color: $r('app.color.shadow_widget'), offsetX: 0, offsetY: 7 })
    .borderRadius(24)
    .clip(true)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: this.abilityName,
        params: { message: 'recent-files' }
      });
    })
  }
}
