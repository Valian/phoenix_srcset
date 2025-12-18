defmodule PhoenixSrcsetTest do
  use ExUnit.Case
  doctest PhoenixSrcset

  describe "variant_path/2" do
    test "generates webp variant path by default" do
      assert PhoenixSrcset.variant_path("/images/photo.png", 800) == "/images/photo_800w.webp"
    end

    test "preserves directory structure" do
      assert PhoenixSrcset.variant_path("/assets/static/images/hero.jpg", 400) ==
               "/assets/static/images/hero_400w.webp"
    end
  end

  describe "variant_path/3" do
    test "allows custom format" do
      assert PhoenixSrcset.variant_path("/images/photo.png", 800, "avif") ==
               "/images/photo_800w.avif"
    end
  end

  describe "srcset/2" do
    test "generates srcset string for multiple widths" do
      result = PhoenixSrcset.srcset("/images/photo.png", [400, 800])

      assert result == "/images/photo_400w.webp 400w, /images/photo_800w.webp 800w"
    end

    test "works with single width" do
      assert PhoenixSrcset.srcset("/images/photo.png", [600]) == "/images/photo_600w.webp 600w"
    end
  end

  describe "srcset/3" do
    test "allows custom format" do
      result = PhoenixSrcset.srcset("/images/photo.png", [400, 800], "avif")

      assert result == "/images/photo_400w.avif 400w, /images/photo_800w.avif 800w"
    end
  end
end
