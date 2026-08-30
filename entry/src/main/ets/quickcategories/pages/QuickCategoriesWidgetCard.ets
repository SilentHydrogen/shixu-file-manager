import { WidgetCategory } from '../../model/WidgetData';

let storage = new LocalStorage();

@Entry(storage)
@Component
struct QuickCategoriesWidgetCard {
  private readonly abilityName: string = 'EntryAbility';
  @LocalStorageProp('totalCount') totalCount: number = 0;
  @LocalStorageProp('pendingCount') pendingCount: number = 0;
  @LocalStorageProp('categoryList') categoryList: WidgetCategory[] = [];

  build() {
    Column() {
      Row() {
        Column() {
          Text('快捷分类')
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
        Text('✧')
          .fontSize($r('app.float.font_size_md'))
          .fontColor($r('app.color.widget_accent_blue'))
          .width(34)
          .height(34)
          .textAlign(TextAlign.Center)
          .backgroundColor($r('app.color.widget_tint_blue'))
          .borderRadius($r('app.float.radius_sm'))
      }
      .width('100%')
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.categoryList, (category: WidgetCategory) => {
          Text(`${category.name} ${category.count}`)
            .fontSize($r('app.float.font_size_micro'))
            .fontColor($r('app.color.widget_accent_blue'))
            .padding({ left: 11, right: 11, top: 9, bottom: 9 })
            .backgroundColor(category.color)
            .borderRadius($r('app.float.radius_sm'))
            .margin({ right: 8, bottom: 8 })
        }, (category: WidgetCategory) => category.name)
        Text(`待整理 ${this.pendingCount}`)
          .fontSize($r('app.float.font_size_micro'))
          .fontColor($r('app.color.widget_accent_amber'))
          .padding({ left: 11, right: 11, top: 9, bottom: 9 })
          .backgroundColor($r('app.color.widget_tint_amber'))
          .borderRadius($r('app.float.radius_sm'))
          .margin({ right: 8, bottom: 8 })
      }
      .width('100%')
      .margin({ top: 16 })
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
        params: { message: 'quick-categories' }
      });
    })
  }
}
