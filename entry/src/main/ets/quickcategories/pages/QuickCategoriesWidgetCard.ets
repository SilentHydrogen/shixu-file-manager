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
      Flex({ wrap: FlexWrap.Wrap }) {
        ForEach(this.categoryList, (category: WidgetCategory) => {
          Text(`${category.name} ${category.count}`)
            .fontSize(12)
            .fontColor('#526B93')
            .padding({ left: 11, right: 11, top: 9, bottom: 9 })
            .backgroundColor(category.color)
            .borderRadius(12)
            .margin({ right: 8, bottom: 8 })
        }, (category: WidgetCategory) => category.name)
        Text(`待整理 ${this.pendingCount}`)
          .fontSize(12)
          .fontColor('#A5763F')
          .padding({ left: 11, right: 11, top: 9, bottom: 9 })
          .backgroundColor('#FFF0DD')
          .borderRadius(12)
          .margin({ right: 8, bottom: 8 })
      }
      .width('100%')
      .margin({ top: 16 })
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
        params: { message: 'quick-categories' }
      });
    })
  }
}