@Component
export struct Icon {
  @Prop source: Resource;
  @Prop iconSize: number = 24;
  @Prop tint: ResourceColor = Color.Black;

  build() {
    Image(this.source)
      .width(this.iconSize)
      .height(this.iconSize)
      .fillColor(this.tint)
      .objectFit(ImageFit.Contain)
  }
}
