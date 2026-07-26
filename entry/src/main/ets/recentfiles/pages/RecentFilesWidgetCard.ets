interface WidgetRecentFile {
  id: number;
  name: string;
  kind: string;
  updated: string;
  tag: string;
  color: string;
  icon: string;
}

let recentFilesStorage = new LocalStorage();

@Entry(recentFilesStorage)
@Component
struct RecentFilesWidgetCard {
  private readonly bundleName: string = 'com.cdyangzheng.filebox';
  private readonly moduleName: string = 'entry';
  private readonly abilityName: string = 'EntryAbility';
  private readonly rowIndexes: number[] = [0, 1];
  @LocalStorageProp('recentFilesJson') recentFilesJson: string = '[]';
  @LocalStorageProp('totalCount') totalCount: number = 0;
  @LocalStorageProp('updatedTime') updatedTime: string = '--:--';

  private recentFiles(): WidgetRecentFile[] {
    try {
      return (JSON.parse(this.recentFilesJson) as WidgetRecentFile[]).slice(0, 4);
    } catch (error) {
      return [];
    }
  }

  @Builder
  private fileCell(file: WidgetRecentFile) {
    FormLink({
      action: 'router',
      bundleName: this.bundleName,
      moduleName: this.moduleName,
      abilityName: this.abilityName,
      params: { message: `open-file:${file.id}` }
    }) {
      Row() {
        Text(file.icon)
          .fontSize(15)
          .fontColor('#526B93')
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .backgroundColor(file.color)
          .borderRadius(9)
        Column() {
          Text(file.name)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#253243')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
          Text(`${file.tag} · ${file.updated}`)
            .fontSize(8)
            .fontColor('#8A96A4')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .margin({ top: 2 })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        .margin({ left: 7 })
      }
      .width('100%')
      .height(40)
      .padding({ left: 7, right: 7 })
      .backgroundColor('#FFFFFFB8')
      .borderRadius(11)
    }
  }

  build() {
    Column() {
      Row() {
        FormLink({
          action: 'router',
          bundleName: this.bundleName,
          moduleName: this.moduleName,
          abilityName: this.abilityName,
          params: { message: 'recent-files' }
        }) {
          Column() {
            Text('最近文件')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor('#16202C')
            Text(`${this.totalCount} 项 · ${this.updatedTime} 已同步`)
              .fontSize(9)
              .fontColor('#7B8795')
              .margin({ top: 2 })
          }
          .alignItems(HorizontalAlign.Start)
        }
        Blank()
        FormLink({
          action: 'router',
          bundleName: this.bundleName,
          moduleName: this.moduleName,
          abilityName: this.abilityName,
          params: { message: 'add-file' }
        }) {
          Text('＋')
            .fontSize(18)
            .fontColor('#526B93')
            .width(30)
            .height(30)
            .textAlign(TextAlign.Center)
            .backgroundColor('#E9F0FF')
            .borderRadius(10)
        }
      }
      .width('100%')

      if (this.recentFiles().length > 0) {
        Column({ space: 6 }) {
          ForEach(this.rowIndexes, (rowIndex: number) => {
            Row({ space: 6 }) {
              if (this.recentFiles().length > rowIndex * 2) {
                Column() {
                  this.fileCell(this.recentFiles()[rowIndex * 2])
                }
                .layoutWeight(1)
              }
              if (this.recentFiles().length > rowIndex * 2 + 1) {
                Column() {
                  this.fileCell(this.recentFiles()[rowIndex * 2 + 1])
                }
                .layoutWeight(1)
              } else {
                Blank().layoutWeight(1)
              }
            }
            .width('100%')
          }, (rowIndex: number) => `${rowIndex}`)
        }
        .width('100%')
        .layoutWeight(1)
        .margin({ top: 9 })
      } else {
        FormLink({
          action: 'router',
          bundleName: this.bundleName,
          moduleName: this.moduleName,
          abilityName: this.abilityName,
          params: { message: 'add-file' }
        }) {
          Text('还没有文件，点击导入')
            .fontSize(11)
            .fontColor('#7B8795')
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
