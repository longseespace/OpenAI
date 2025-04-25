//
//  ImageEditsQuery.swift
//  
//
//  Created by Aled Samuel on 24/04/2023.
//

import Foundation

public struct ImageEditsQuery: Codable {
    public typealias ResponseFormat = ImagesQuery.ResponseFormat
    public typealias Size = ImagesQuery.Size
    public typealias Quality = ImagesQuery.Quality

    /// The image(s) to edit. Must be supported image file(s) (e.g., PNG, JPG, WEBP).
    /// For `gpt-image-1`, each image must be less than 25MB.
    /// For `dall-e-2`, you can only provide one image, which must be a square PNG file less than 4MB.
    /// If mask is not provided, image(s) must have transparency, which will be used as the mask.
    public let image: [Data]
    /// An additional image whose fully transparent areas (e.g. where alpha is zero) indicate where image should be edited. Must be a valid PNG file, less than 4MB, and have the same dimensions as image.
    /// Note: Mask functionality might behave differently or not be supported with multi-image inputs. Refer to the latest OpenAI documentation.
    public let mask: Data?
    /// A text description of the desired image(s). The maximum length is 1000 characters.
    public let prompt: String
    /// The model to use for image generation. (e.g., "dall-e-2", "gpt-image-1")
    /// Defaults to dall-e-2
    public let model: Model?
    /// The number of images to generate. Must be between 1 and 10. (DALL·E 2 only)
    public let n: Int?
    /// The quality of the image that will be generated. `high`, `medium` and `low` are only supported for `gpt-image-1`. `dall-e-2` only supports `standard` quality. Defaults to `auto`.
    public let quality: Quality?
    /// The format in which the generated images are returned. Must be one of url or b64_json.
    /// Defaults to url
    public let responseFormat: Self.ResponseFormat?
    /// The size of the generated images. Must be one of 256x256, 512x512, or 1024x1024. (DALL·E 2 only)
    public let size: Size?
    /// A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
    /// https://platform.openai.com/docs/guides/safety-best-practices/end-user-ids
    public let user: String?

    public init(
        image: [Data],
        prompt: String,
        mask: Data? = nil,
        model: Model? = nil,
        n: Int? = nil,
        quality: Quality? = nil,
        responseFormat: Self.ResponseFormat? = nil,
        size: Self.Size? = nil,
        user: String? = nil
    ) {
        self.image = image
        self.mask = mask
        self.prompt = prompt
        self.model = model
        self.n = n
        self.quality = quality
        self.responseFormat = responseFormat
        self.size = size
        self.user = user
    }
    
    // Convenience initializer for single image (common for dall-e-2)
    public init(
        image: Data,
        prompt: String,
        mask: Data? = nil,
        model: Model? = nil,
        n: Int? = nil,
        quality: Quality? = nil,
        responseFormat: Self.ResponseFormat? = nil,
        size: Self.Size? = nil,
        user: String? = nil
    ) {
        self.init(image: [image], prompt: prompt, mask: mask, model: model, n: n, quality: quality, responseFormat: responseFormat, size: size, user: user)
    }

    public enum CodingKeys: String, CodingKey {
        case image
        case mask
        case prompt
        case model
        case n
        case responseFormat = "response_format"
        case size
        case user
        case quality
    }
}

extension ImageEditsQuery: MultipartFormDataBodyEncodable {
    func encode(boundary: String) -> Data {
        var entries: [MultipartFormDataEntry] = []
        
        // Add each image as a file part
        for (index, imageData) in image.enumerated() {
            // Determine file extension/content type (basic PNG assumption, might need improvement)
            let fileName = "image_\(index).png"
            let contentType = "image/png" // Consider making this dynamic based on Data or adding a parameter
            entries.append(MultipartFormDataEntry.file(paramName: "image", fileName: fileName, fileData: imageData, contentType: contentType))
        }
        
        // Add mask if present
        if let maskData = mask {
            entries.append(MultipartFormDataEntry.file(paramName: "mask", fileName: "mask.png", fileData: maskData, contentType: "image/png"))
        }
        
        // Add other string parameters
        entries.append(MultipartFormDataEntry.string(paramName: "prompt", value: prompt))
        if let modelValue = model { // Model is String, use directly
             entries.append(MultipartFormDataEntry.string(paramName: "model", value: modelValue))
        }
        if let nValue = n {
            entries.append(MultipartFormDataEntry.string(paramName: "n", value: String(nValue)))
        }
        if let responseFormatValue = responseFormat?.rawValue { // Assuming ResponseFormat conforms to RawRepresentable<String>
            entries.append(MultipartFormDataEntry.string(paramName: "response_format", value: responseFormatValue))
        }
        if let sizeValue = size?.rawValue { // Assuming Size conforms to RawRepresentable<String>
             entries.append(MultipartFormDataEntry.string(paramName: "size", value: sizeValue))
        }
        if let userValue = user {
            entries.append(MultipartFormDataEntry.string(paramName: "user", value: userValue))
        }
        if let qualityValue = quality?.rawValue {
            entries.append(MultipartFormDataEntry.string(paramName: "quality", value: qualityValue))
        }

        let bodyBuilder = MultipartFormDataBodyBuilder(boundary: boundary, entries: entries)
        return bodyBuilder.build()
    }
}
