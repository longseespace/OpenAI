//
//  ImagesQuery.swift
//
//
//  Created by Sergii Kryvoblotskyi on 02/04/2023.
//

import Foundation

/// Given a prompt and/or an input image, the model will generate a new image.
/// https://platform.openai.com/docs/api-reference/images/create
public struct ImagesQuery: Codable, Equatable {

    public enum ResponseFormat: String, Codable, Equatable {
        case url
        case b64_json
    }
    
    public enum Background: String, Codable, Equatable, CaseIterable {
        case transparent
        case opaque
        case auto
    }
    
    public enum OutputFormat: String, Codable, Equatable, CaseIterable {
        case png
        case jpeg
        case webp
    }

    /// A text description of the desired image(s). The maximum length is 1000 characters for dall-e-2 and 4000 characters for dall-e-3.
    public let prompt: String
    /// The model to use for image generation.
    /// Defaults to dall-e-2
    public let model: Model?
    /// The format in which the generated images are returned (URL or base64-encoded JSON).
    /// Defaults to url
    public let responseFormat: Self.ResponseFormat?
    /// The number of images to generate. Must be between 1 and 10. For dall-e-3, only n=1 is supported.
    /// Defaults to 1
    public let n: Int?
    /// The size of the generated images. Must be one of 256x256, 512x512, or 1024x1024 for dall-e-2. Must be one of 1024x1024, 1792x1024, or 1024x1792 for dall-e-3 models.
    /// Defaults to 1024x1024
    public let size: Self.Size?
    /// A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
    /// https://platform.openai.com/docs/guides/safety-best-practices/end-user-ids
    public let user: String?
    /// The style of the generated images. Must be one of vivid or natural. Vivid causes the model to lean towards generating hyper-real and dramatic images. Natural causes the model to produce more natural, less hyper-real looking images. This param is only supported for dall-e-3.
    /// Defaults to vivid
    public let style: Self.Style?
    /// The quality of the image that will be generated.
    /// `auto` (default) selects the best quality for the model.
    /// `high`, `medium`, `low` are supported for `gpt-image-1`.
    /// `hd`, `standard` are supported for `dall-e-3`.
    /// `standard` is the only option for `dall-e-2`.
    public let quality: Self.Quality?
    /// Allows setting transparency for the background. Only supported for `gpt-image-1`.
    /// Requires `outputFormat` to be `png` or `webp` if set to `transparent`.
    /// Defaults to `auto`.
    public let background: Self.Background?
    /// The compression level (0-100) for the generated images. Only supported for `gpt-image-1` with `webp` or `jpeg` `outputFormat`.
    /// Defaults to 100.
    public let outputCompression: Int?
    /// The format of the generated image data itself. Only supported for `gpt-image-1`.
    /// Defaults to `png`.
    public let outputFormat: Self.OutputFormat?

    public init(
        prompt: String,
        model: Model? = nil,
        n: Int? = nil,
        quality:Self.Quality? = nil,
        responseFormat: Self.ResponseFormat? = nil,
        size: Size? = nil,
        style: Self.Style? = nil,
        user: String? = nil,
        background: Self.Background? = nil,
        outputCompression: Int? = nil,
        outputFormat: Self.OutputFormat? = nil
    ) {
        self.prompt = prompt
        self.model = model
        self.n = n
        self.quality = quality
        self.responseFormat = responseFormat
        self.size = size
        self.style = style
        self.user = user
        self.background = background
        self.outputCompression = outputCompression
        self.outputFormat = outputFormat
    }

    public enum CodingKeys: String, CodingKey {
        case model
        case prompt
        case n
        case size
        case user
        case style
        case responseFormat = "response_format"
        case quality
        case background
        case outputCompression = "output_compression"
        case outputFormat = "output_format"
    }

    public enum Style: String, Codable, CaseIterable {
        case natural
        case vivid
    }

    public enum Quality: String, Codable, CaseIterable {
        case auto // Default
        case high // gpt-image-1
        case medium // gpt-image-1
        case low // gpt-image-1
        case standard // dall-e-3, dall-e-2
        case hd // dall-e-3
    }

    public enum Size: String, Codable, CaseIterable {
        case _256 = "256x256"
        case _512 = "512x512"
        case _1024 = "1024x1024"
        case _1792_1024 = "1792x1024" // for dall-e-3 models
        case _1024_1792 = "1024x1792" // for dall-e-3 models
    }
}
