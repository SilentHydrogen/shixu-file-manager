interface WidgetCategoryItem {
  name: string;
  color: string;
  icon: string;
  count: number;
}

let quickCategoriesStorage = new LocalStorage();

@Entry(quickCategoriesStorage)
@Component
struct QuickCategoriesWidgetCard {
  private readonly bundleName: string = 'com.cdyangzheng.filebox';
  private readonly moduleName: string = 'entry';
  private readonly abilityName: string = 'EntryAbility';
  private readonly rowIndexes: number[] = [0, 1];
  @LocalStorageProp('categoriesJson') categoriesJson: string = '[]';
  @LocalStorageProp('totalCount') totalCount: number = 0;

  private categories(): WidgetCategoryItem[] {
    try {
      return (JSON.parse(this.categoriesJson) as WidgetCategoryItem[]).slice(0, 6);
    } catch (error) {
      return [];
    }
  }

  @Builder
  private categoryCell(category: WidgetCategoryItem) {
    FormLink({
      action: 'router',
      bundleName: this.bundleName,
      moduleName: this.moduleName,
      abilityName: this.abilityName,
      params: { message: `category:${category.name}` }
    }) {
      Row() {
        Text(category.icon)
          .fontSize(12)
          .fontColor('#526B93')
          .margin({ right: 5 })
        Text(category.name)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor('#526174')
          .maxLines(1)
          .layoutWeight(1)
        Text(`${category.count}`)
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .fontColor('#607B9F')
      }
      .width('100%')
      .height(38)
      .padding({ left: 8, right: 8 })
      .backgroundColor(category.color)
      .borderRadius(11)
    }
  }

  build() {
    Column() {
      FormLink({
        action: 'router',
        bundleName: this.bundleName,
        moduleName: this.moduleName,
        abilityName: this.abilityName,
        params: { message: 'quick-categories' }
      }) {
        Row() {
          Column() {
            Text('快捷分类')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#16202C')
            Text(`${this.totalCount} 个文件 · 点标签直达`)
              .fontSize(9)
              .fontColor('#7B8795')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          Blank()
          Text('◇')
            .fontSize(17)
            .fontColor('#607B9F')
            .width(30)
            .height(30)
            .textAlign(TextAlign.Center)
            .backgroundColor('#E9F0FF')
            .borderRadius(10)
        }
        .width('100%')
      }

      if (this.categories().length > 0) {
        Column({ space: 7 }) {
          ForEach(this.rowIndexes, (rowIndex: number) => {
            Row({ space: 7 }) {
              if (this.categories().length > rowIndex * 3) {
                Column() {
                  this.categoryCell(this.categories()[rowIndex * 3])
                }.layoutWeight(1)
              }
              if (this.categories().length > rowIndex * 3 + 1) {
                Column() {
                  this.categoryCell(this.categories()[rowIndex * 3 + 1])
                }.layoutWeight(1)
              } else {
                Blank().layoutWeight(1)
              }
              if (this.categories().length > rowIndex * 3 + 2) {
                Column() {
                  this.categoryCell(this.categories()[rowIndex * 3 + 2])
                }.layoutWeight(1)
              } else {
                Blank().layoutWeight(1)
              }
            }
            .width('100%')
          }, (rowIndex: number) => `${rowIndex}`)
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 10 })
      } else {
        FormLink({
          action: 'router',
          bundleName: this.bundleName,
          moduleName: this.moduleName,
          abilityName: this.abilityName,
          params: { message: 'quick-categories' }
        }) {
          Text('导入文件后显示实时分类')
            .fontSize(10)
            .fontColor('#8A96A4')
            .width('100%')
            .layoutWeight(1)
            .textAlign(TextAlign.Center)
        }
      }
    }
    .width('100%')
    .height('100%')
    .padding(12)
    .backgroundColor('#F9FBFFF0')
    .backgroundBlurStyle(BlurStyle.Thick)
    .border({ width: 1, color: '#FFFFFFC9', radius: 20 })
    .shadow({ radius: 14, color: '#13243A20', offsetX: 0, offsetY: 5 })
    .borderRadius(20)
  }
}
